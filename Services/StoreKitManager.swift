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
                debug("Transaction.update → active=\(active), expires=\(String(describing: t.expirationDate)), revoked=\(t.revocationDate != nil)")
                await setPro(active)
                scheduleExpiryCheck(for: active ? t.expirationDate : nil, willAutoRenew: true) // we don't know willAutoRenew from this path; keep true to avoid premature schedule
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
        if let product = proProduct, let sub = product.subscription {
            do {
                let rawStatuses = try await sub.status

                var isActive = false
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
                    if activeForState { isActive = true }

                    if latestTransaction == nil ||
                        (latestTransaction!.expirationDate ?? .distantPast) < (t.expirationDate ?? .distantPast) {
                        latestTransaction = t
                        latestRenewalInfo = ri
                    }
                }

                let exp = latestTransaction?.expirationDate
                let willAutoRenew = latestRenewalInfo?.willAutoRenew ?? false

                debug("statusAPI → active=\(isActive), willAutoRenew=\(willAutoRenew), exp=\(String(describing: exp))")

                await setPro(isActive)
                scheduleExpiryCheck(for: isActive ? exp : nil, willAutoRenew: willAutoRenew)
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
                let active = (t.revocationDate == nil) && (t.expirationDate == nil || t.expirationDate! > Date())
                debug("currentEntitlement → active=\(active), exp=\(String(describing: t.expirationDate))")
                await setPro(active)
                scheduleExpiryCheck(for: active ? t.expirationDate : nil, willAutoRenew: true)
            } else {
                debug("no entitlement present → set false")
                scheduleExpiryCheck(for: nil, willAutoRenew: false)
                await setPro(false)
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
        guard let date = date else { return }
        guard !willAutoRenew else { return }
        let delay = max(0, date.timeIntervalSinceNow + 1.0)
        expiryTask = Task { [weak self] in
            let ns = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            await self?.refreshEntitlement()
            self?.debug("expiry check fired → refreshEntitlement()")
        }
        debug("scheduled expiry check at: \(date)")
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

    private func setPro(_ value: Bool) async {
        await MainActor.run { self.isSubscribed = value }
        await updateProStatusInFirebase(isPro: value)
    }

    @MainActor
    private func updateProStatusInFirebase(isPro: Bool) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if lastUid == uid, lastIsProWritten == isPro { return }
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(uid).updateData(["isPro": isPro])
            lastUid = uid
            lastIsProWritten = isPro
            debug("wrote isPro=\(isPro) for uid=\(uid)")
        } catch {
            debug("firestore write error: \(error.localizedDescription)")
        }
    }
}
