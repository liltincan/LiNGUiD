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
        VStack(spacing: 32) {
            Image(systemName: "star.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.purple)
                .padding(.top, 40)

            Text("Unlock LiNGUiD Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Get unlimited access to all features for just $12.99!")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                Label("Unlimited practice sessions", systemImage: "bolt.fill")
                Label("Exclusive content", systemImage: "lock.open.fill")
                Label("Priority support", systemImage: "person.crop.circle.badge.checkmark")
            }
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                purchasePro()
            }) {
                Text(isPurchasing ? "Processing..." : "Get Pro for $12.99")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .disabled(isPurchasing || products.isEmpty)
            .padding(.top, 8)

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

            Spacer()
        }
        .padding()
        .navigationTitle("Go Pro")
        .task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: ["LiNGUID.Pro"])
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
