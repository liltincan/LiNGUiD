//
//  SavedWordsViewModel.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/30/25.
//

import Combine
import FirebaseFirestore
import Foundation

enum WordType {
    case known
    case unknown
}

@MainActor
class SavedLangViewModel: ObservableObject {

    @Published var languageData: [String: LanguageEntry] = [:]
    @Published var selectedLanguage: String = "de"  // or "de"
    @Published var selectedTab: WordType = .known
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func fetchLanguageData(for userID: String) async {
        let docRef = db.collection("users").document(userID)

        do {
            let snapshot = try await docRef.getDocument()
            let data = try snapshot.data(as: FirestoreLanguageData.self)
            self.languageData = data.languageData
        } catch {
            self.errorMessage =
                "Failed to fetch data: \(error.localizedDescription)"
        }

    }
}
