//
//  UserSessionViewModel.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/30/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
class UserSessionViewModel: ObservableObject {

    @Published var currentUser: User?
    private let firestoreService = FirestoreService.shared

    init() {
        getCurrentUser()
    }
    
    func checkUserExists() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            return false
        }
        return await FirebaseAuthService.shared.userDocumentExists(uid: uid)
    }

    func getCurrentUser() {  //talks to firebase service to fetch user data
        firestoreService.getCurrentUser { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.currentUser = user  //sets current values to db values
                case .failure(let error):
                    print(
                        "Failed to get current user: \(error.localizedDescription)"
                    )  //explain if unable to access
                }
            }
        }
    }
    
    func refreshUser() async {
        await withCheckedContinuation { continuation in
            firestoreService.getCurrentUser { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        self.currentUser = user
                    case .failure(let error):
                        print(
                            "Failed to get current user: \(error.localizedDescription)"
                        )
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func clearUserData() {
        currentUser = nil
    }
}
