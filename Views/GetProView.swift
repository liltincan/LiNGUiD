import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseFirestore

struct GetProView: View {
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccess = false
    @State private var products: [Product] = []
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)? = nil
    var fromSettings: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Logo Section
            Image("linguid_pro_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 160)
                .padding(.top, 10)

            Text("for just $12.99 / mo")
                .font(.title3)
                .foregroundColor(.white.opacity(0.85))

            // Feature List
            VStack(alignment: .leading, spacing: 18) {
                feature(icon: "globe", text: "Unlimited Target Languages")
                feature(icon: "infinity", text: "Infinite Translations Every Day")
                feature(icon: "nosign", text: "Ad-Free")
                feature(icon: "checkmark.seal.fill", text: "Account Verification")
                feature(icon: "sparkles", text: "Early Access to New Features")
            }

            // Purchase Button
            Button(action: {
                //purchasePro()
                Task {
                    await updateProStatusInFirebase()
                    onDone?()
                    if(fromSettings){
                        dismiss()
                    }
                }
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

            if let error = purchaseError {
                Text(error).foregroundColor(.red)
            }

            if showSuccess {
                Text("Purchase successful!").foregroundColor(.green)
            }

            Spacer()
        }
        .padding()
        .background(
            Color(red: 22/255, green: 0/255, blue: 46/255)
                .cornerRadius(24)
        )
        .frame(maxHeight: .infinity, alignment: .top)
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
        guard let product = products.first(where: { $0.id == "LiNGUiD.Pro" }) else {
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
                    purchaseError = "Purchase failed."
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
            purchaseError = "Failed to update Pro status."
        }
    }
}
