//
//  ProStatusViewModel.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/4/25.
//

import FirebaseFirestore

class ProStatusViewModel: ObservableObject {
    @Published var isPro: Bool = false
    private var listener: ListenerRegistration?

    func startListening(uid: String) {
        let db = Firestore.firestore()
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error listening for isPro updates: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else {
                print("No user data found")
                return
            }

            // Handle String or Bool case
            if let boolValue = data["isPro"] as? Bool {
                self.isPro = boolValue
            } else if let stringValue = data["isPro"] as? String {
                self.isPro = stringValue.lowercased() == "true"
            } else {
                self.isPro = false
            }
        }
    }

    func stopListening() {
        listener?.remove()
    }
}
