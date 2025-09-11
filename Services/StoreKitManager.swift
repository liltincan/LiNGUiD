import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore
import UIKit
import Combine

final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    private init() {}
    
    private let productID = "LiNGUiD.Pro"

    @Published private(set) var isSubscribed: Bool = false
    private var proProduct: Product?
    private var updatesTask: Task<Void, Never>?
    private var started = false
    private var lastIsProWritten: Bool?
    private var lastUid: String?
    private var activeTicker: AnyCancellable?
    private var expiryTask: Task<Void, Never>?
    private var pendingLapseAt: Date?
    private var proLockUntil: Date?
    private var falseDebounceStart: Date?
    private let falseDebounceWindow: TimeInterval = 5
    
    @Published private(set) var expirationDate: Date?
    @Published private(set) var willAutoRenew: Bool?

    func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(significantTimeChange), name: UIApplication.significantTimeChangeNotification, object: nil)

        updatesTask = Task { await listenForUpdates() }
        Task { await loadProducts(); await refreshEntitlement() }

        debug("started")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        updatesTask?.cancel()
        stopActiveTicker()
        expiryTask?.cancel()
    }

    @MainActor
    func refreshNow() {
        Task { await refreshEntitlement() }
    }

    private func listenForUpdates() async {
        for await update in StoreKit.Transaction.updates {
            do {
                let t: StoreKit.Transaction = try checkVerified(update)
                guard t.productID == productID else { continue }

                let active = isActive(t)
                debug("tx.update → active=\(active), exp=\(String(describing: t.expirationDate)), revoked=\(t.revocationDate != nil)")
                await setPro(active, reason: "tx.update")
                scheduleExpiryCheck(for: active ? t.expirationDate : nil, willAutoRenew: true)
                await t.finish()
            } catch {
                debug("update verify error: \(error.localizedDescription)")
            }
        }
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: [productID])
            proProduct = products.first
            debug("loaded product: \(proProduct?.id ?? "nil")")
        } catch {
            debug("product load error: \(error.localizedDescription)")
        }
    }

    @objc private func appDidBecomeActive() {
        startActiveTicker()
        Task { await refreshEntitlement() }
    }

    @objc private func appWillResignActive() {
        stopActiveTicker()
    }

    @objc private func appWillEnterForeground() {
        Task { await refreshEntitlement() }
    }

    @objc private func significantTimeChange() {
        Task { await refreshEntitlement() }
    }

    private func isActive(_ t: StoreKit.Transaction) -> Bool {
        (t.revocationDate == nil) && (t.expirationDate == nil || t.expirationDate! > Date())
    }

    func refreshEntitlement() async {
        let now = Date()

        if let product = proProduct, let sub = product.subscription {
            do {
                let rawStatuses = try await sub.status

                var isActiveFlag = false
                var latestTransaction: StoreKit.Transaction?
                var latestRenewalInfo: Product.SubscriptionInfo.RenewalInfo?

                for s in rawStatuses {
                    guard let t: StoreKit.Transaction = try? checkVerified(s.transaction) else { continue }
                    let ri: Product.SubscriptionInfo.RenewalInfo? = try? checkVerified(s.renewalInfo)

                    let activeForState: Bool
                    if #available(iOS 16.0, *) {
                        activeForState = (s.state == .subscribed || s.state == .inGracePeriod || s.state == .inBillingRetryPeriod)
                    } else {
                        activeForState = (s.state == .subscribed || s.state == .inGracePeriod)
                    }
                    if activeForState { isActiveFlag = true }

                    if latestTransaction == nil ||
                        (latestTransaction!.expirationDate ?? .distantPast) < (t.expirationDate ?? .distantPast) {
                        latestTransaction = t
                        latestRenewalInfo = ri
                    }
                }

                let exp = latestTransaction?.expirationDate
                let willAutoRenew = latestRenewalInfo?.willAutoRenew ?? false

                if let exp, !willAutoRenew, exp > now {
                    pendingLapseAt = exp
                } else if willAutoRenew {
                    pendingLapseAt = nil
                }
                
                await MainActor.run {
                  self.expirationDate = exp
                  self.willAutoRenew = willAutoRenew
                }

                let effectiveActive = isActiveFlag || (pendingLapseAt != nil && pendingLapseAt! > now)

                debug("statusAPI → active=\(isActiveFlag) → effective=\(effectiveActive), willAutoRenew=\(willAutoRenew), exp=\(String(describing: exp)), pendingLapseAt=\(String(describing: pendingLapseAt))")

                await setPro(effectiveActive, reason: "statusAPI")
                scheduleExpiryCheck(for: effectiveActive ? exp : nil, willAutoRenew: willAutoRenew)
                return
            } catch {
                debug("statusAPI error: \(error.localizedDescription)")
            }
        }

        do {
            var latest: StoreKit.Transaction?
            for await result in StoreKit.Transaction.currentEntitlements {
                let t: StoreKit.Transaction = try checkVerified(result)
                if t.productID == productID {
                    if latest == nil || (latest!.expirationDate ?? .distantPast) < (t.expirationDate ?? .distantPast) {
                        latest = t
                    }
                }
            }

            if let t = latest {
                let active = isActive(t)
                let effectiveActive = active || (pendingLapseAt != nil && pendingLapseAt! > now)
                
                await MainActor.run {
                    self.expirationDate = t.expirationDate
                    self.willAutoRenew  = true
                }
                
                debug("currentEntitlement → active=\(active) → effective=\(effectiveActive), exp=\(String(describing: t.expirationDate)), pendingLapseAt=\(String(describing: pendingLapseAt))")
                await setPro(effectiveActive, reason: "currentEntitlements")
                scheduleExpiryCheck(for: effectiveActive ? t.expirationDate : nil, willAutoRenew: true)
            } else {
                await MainActor.run {
                    self.expirationDate = nil
                    self.willAutoRenew  = nil
                }
                
                if let until = pendingLapseAt, until > now {
                    debug("no entitlement present, but pendingLapseAt=\(until) in future → keep Pro true")
                    await setPro(true, reason: "noEntitlement/locked")
                    scheduleExpiryCheck(for: until, willAutoRenew: false)
                } else {
                    debug("no entitlement present & no pending lapse → set false")
                    scheduleExpiryCheck(for: nil, willAutoRenew: false)
                    await setPro(false, reason: "noEntitlement")
                }
            }
        } catch {
            debug("entitlement scan error: \(error.localizedDescription)")
        }
    }

    private func startActiveTicker() {
        stopActiveTicker()
        activeTicker = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { await self.refreshEntitlement() }
            }
        debug("active ticker started")
    }

    private func stopActiveTicker() {
        activeTicker?.cancel()
        activeTicker = nil
        debug("active ticker stopped")
    }

    private func scheduleExpiryCheck(for date: Date?, willAutoRenew: Bool) {
        expiryTask?.cancel()
        guard let date = date else { pendingLapseAt = nil; proLockUntil = nil; return }
        guard !willAutoRenew else { pendingLapseAt = nil; proLockUntil = nil; return }

        pendingLapseAt = date
        proLockUntil = date.addingTimeInterval(2) // 2s safety buffer past expiry

        let delay = max(0, date.timeIntervalSinceNow + 1.0)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.refreshEntitlement()
            self?.pendingLapseAt = nil
            self?.proLockUntil = nil // unlock after reevaluating at/after expiry
            self?.debug("expiry check fired → refreshEntitlement()")
        }
        debug("scheduled expiry check at: \(date) (lock until \(proLockUntil!))")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let err): throw err
        case .verified(let signed): return signed
        }
    }

    private func debug(_ msg: String) {
        print("[StoreKitManager] \(msg)")
    }

    private func setPro(_ value: Bool, reason: String? = nil) async {
        let now = Date()

        if value == false {
            if let lock = proLockUntil, now < lock {
                debug("blocked false (locked until \(lock)) reason=\(reason ?? "-")")
                return
            }
            if falseDebounceStart == nil {
                falseDebounceStart = now
                debug("false proposed; starting debounce (\(falseDebounceWindow)s). reason=\(reason ?? "-")")
                return
            } else if now.timeIntervalSince(falseDebounceStart!) < falseDebounceWindow {
                debug("false within debounce window; skipping write. reason=\(reason ?? "-")")
                return
            }
            falseDebounceStart = nil
        } else {
            falseDebounceStart = nil
        }

        await MainActor.run { self.isSubscribed = value }
        await updateProStatusInFirebase(isPro: value)
    }

    private func updateProStatusInFirebase(isPro: Bool) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if lastUid == uid, lastIsProWritten == isPro { return }
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(uid).updateData(["isPro": isPro])
            lastUid = uid
            lastIsProWritten = isPro
            debug("wrote isPro=\(isPro) for uid=\(uid)")
            if !isPro {
                await clampTargetLanguagesToCurrent(for: uid, db: db)
            }
        } catch {
            debug("firestore write error: \(error.localizedDescription)")
        }
    }
    
    private func clampTargetLanguagesToCurrent(for uid: String, db: Firestore) async {
        let ref = db.collection("users").document(uid)
        do {
            let snap = try await ref.getDocument()
            guard let data = snap.data() else {
                        debug("clamp: no user doc for uid=\(uid)")
                        return
            }
            if let current = data["targetLanguage"] as? String {
                try await ref.updateData(["targetLanguageList": [current]])
                debug("clamp: set targetLanguageList = [\(current)] for uid=\(uid)")
            } else if let list = data["targetLanguageList"] as? [String], let first = list.first {
                try await ref.updateData(["targetLanguage": first, "targetLanguageList": [first]])
                debug("clamp: targetLanguage missing; set to \(first) and clamped list for uid=\(uid)")
            } else {
                debug("clamp: no targetLanguage or list to clamp for uid=\(uid)")
            }
        } catch {
            debug("clamp error: \(error.localizedDescription)")
        }
    }
}

