import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseFirestore

struct GetProView: View {
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccess = false
    @State private var products: [Product] = []

    var body: some View {
        ZStack {
            // Match the background color exactly to the logo's background (use #16002E)
            Color(red: 22/255, green: 0/255, blue: 46/255)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Image("linguid_pro_logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 585, height: 320)
                        .padding(.top, 15) // Move logo down 15px
                    VStack(spacing: 0) {
                        Spacer().frame(height: 620)
                        Text("for just $12.99")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                            .padding(.top, 130) // Move down 30px more
                    }
                    .frame(height: 320, alignment: .top)
                }

                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "globe")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                        Text("Unlimited Target Languages")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "infinity")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                        Text("Infinite Translations Every Day")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "nosign")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                        Text("Ad-Free")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                        Text("Account Verification")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                            .font(.system(size: 22, weight: .bold))
                        Text("Early Access to New Features")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 32)

                Spacer()

                HStack {
                    Spacer()
                    Button(action: {
                        purchasePro()
                    }) {
                        Text(isPurchasing ? "Processing..." : "Go Pro")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 40/255, green: 0/255, blue: 60/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(Color.white)
                                    .shadow(color: Color.white.opacity(0.25), radius: 12, x: 0, y: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .frame(width: 320) // Restrict button width
                    .disabled(isPurchasing || products.isEmpty)
                    Spacer()
                }
                .padding(.bottom, 40)

                if let error = purchaseError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }

                if showSuccess {
                    Text("Purchase successful! Enjoy Pro features.")
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: ["LiNGUiD.Pro"])
            await MainActor.run {
                self.products = storeProducts
            }
        } catch {
            await MainActor.run {
                self.purchaseError = "Failed to load products."
            }
        }
    }

    func purchasePro() {
        guard let product = products.first(where: { $0.id == "LiNGUID.Pro" }) else {
            purchaseError = "Pro product not found."
            return
        }
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(_):
                    showSuccess = true
                    await updateProStatusInFirebase()
                case .userCancelled, .pending:
                    purchaseError = "Purchase cancelled or pending."
                default:
                    purchaseError = "Purchase failed. Please try again."
                }
            } catch {
                purchaseError = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    func updateProStatusInFirebase() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(uid).updateData(["isPro": true])
        } catch {
            purchaseError = "Failed to update Pro status. Please contact support."
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
        )
    }
}

#if DEBUG
struct GetProView_Previews: PreviewProvider {
    static var previews: some View {
        GetProView()
    }
}
#endif
