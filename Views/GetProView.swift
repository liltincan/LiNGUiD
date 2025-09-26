import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseFirestore

private enum LegalSheet: Identifiable {
    case terms, privacy
    var id: Int { hashValue }
}

struct GetProView: View {
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccess = false
    @State private var products: [Product] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var onDone: (() -> Void)? = nil
    var fromSettings: Bool = false

    private let productID = "linguid.subscription"
    @State private var proProduct: Product?
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 24) {
            // Logo Section
            Image("linguid_pro_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 160)
                .padding(.top, 10)

            Text(displayPriceLine())
                .font(.title3)
                .foregroundColor(.white.opacity(0.85))

            // Feature List
            VStack(alignment: .leading, spacing: 18) {
                feature(icon: "globe", text: "Up to 3 Target Languages")
                feature(icon: "infinity", text: "Infinite Translations Every Day")
                feature(icon: "nosign", text: "Ad-Free")
                feature(icon: "checkmark.seal.fill", text: "Account Verification")
                feature(icon: "sparkles", text: "Early Access to New Features")
            }

            // Purchase Button
            Button(action: {
                Task { await purchasePro() }
            }) {
                Text(isPurchasing ? "Processing..." : "Go Pro")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 40/255, green: 0/255, blue: 60/255))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .disabled(isPurchasing || proProduct == nil)

            // Restore purchases
            Button {
                Task { await restorePurchases() }
            } label: {
                Text(isRestoring ? "Restoring..." : "Restore Purchases")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .disabled(isRestoring)

            if let error = purchaseError {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation { purchaseError = nil }
                        }
                    }
            }

            if showSuccess {
                Text("Purchase successful!")
                    .foregroundColor(.green)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation { showSuccess = false }
                        }
                    }
            }

            Spacer()
            
            VStack(spacing: 6) {
                  Text("Payment will be charged to your Apple ID. Subscription auto-renews unless canceled at least 24 hours before the end of the current period. You can manage or cancel your subscription in the App Store.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                  HStack(spacing: 16) {
                      Button {
                          if let url = URL(string: "https://learnwithlinguid.com/") {
                              openURL(url)
                          }
                      } label: {
                          Text("Terms of Service")
                              .fontWeight(.medium)
                              .underline(true, color: .white)
                              .foregroundColor(.white)
                      }
                      .buttonStyle(.plain)

                      Text("|")
                          .foregroundColor(.gray)
                      
                      Button {
                          if let url = URL(string: "https://learnwithlinguid.com/") {
                              openURL(url)
                          }
                      } label: {
                          Text("Privacy Policy")
                              .fontWeight(.medium)
                              .underline(true, color: .white)
                              .foregroundColor(.white)
                      }
                      .buttonStyle(.plain)
                  }
                  .font(.footnote)
                  .multilineTextAlignment(.center)
            }
            .padding(.top, -20)
        }
        .padding()
        .background(
            Color(Color.appSecondaryColor)
                .cornerRadius(24)
        )
        .frame(maxHeight: .infinity, alignment: .top)

        .task {
            await loadProducts()
            StoreKitManager.shared.refreshNow()
        }

        .onChange(of: scenePhase) { phase in
            if phase == .active {
                StoreKitManager.shared.refreshNow()
            }
        }
    }

    func feature(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func displayPriceLine() -> String {
        if let p = proProduct, let sub = p.subscription {
            return "\(p.displayPrice) / \(sub.subscriptionPeriod.unit.displayName)"
        }
        return "Loading price..."
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [productID])
            await MainActor.run {
                self.products = storeProducts
                self.proProduct = storeProducts.first(where: { $0.id == productID })
                if products.isEmpty {
                    self.purchaseError = "Couldn't find product \(productID)."
                }
            }
        } catch {
            await MainActor.run { self.purchaseError = "Failed to load products: \(error.localizedDescription)" }
        }
    }

    func purchasePro() async {
        guard let product = proProduct else {
            await MainActor.run { purchaseError = "Pro product not found." }
            return
        }

        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
            showSuccess = false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction: StoreKit.Transaction = try checkVerified(verification)

                await transaction.finish()
                StoreKitManager.shared.refreshNow()

                await MainActor.run {
                    showSuccess = true
                    onDone?()
                    if fromSettings { dismiss() }
                }

            case .userCancelled:
                await MainActor.run { purchaseError = "Purchase cancelled." }

            case .pending:
                await MainActor.run { purchaseError = "Purchase pending. You'll be notified when it completes." }

            default:
                await MainActor.run { purchaseError = "Purchase failed." }
            }
        } catch {
            await MainActor.run { purchaseError = error.localizedDescription }
        }

        await MainActor.run { isPurchasing = false }
    }

    func restorePurchases() async {
        await MainActor.run {
            isRestoring = true
            purchaseError = nil
        }
        do {
            try? await AppStore.sync()

            var restored = false
            for await result in StoreKit.Transaction.currentEntitlements {
                let t: StoreKit.Transaction = try checkVerified(result)
                if t.productID == productID {
                    restored = true
                }
            }

            StoreKitManager.shared.refreshNow()

            if !restored {
                await MainActor.run { purchaseError = "No active subscription found to restore." }
            } else {
                await MainActor.run { showSuccess = true }
            }
        } catch {
            await MainActor.run { purchaseError = "Restore failed: \(error.localizedDescription)" }
        }
        await MainActor.run { isRestoring = false }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let err):
            throw err
        case .verified(let signed):
            return signed
        }
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Mo"
        case .year: return "Year"
        @unknown default: return "Period"
        }
    }
}
