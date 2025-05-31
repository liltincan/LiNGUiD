//
//  SavedWordsViewModel.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/30/25.
//

import Combine
import FirebaseFirestore
import Foundation
import FirebaseAuth

enum WordType {
    case known
    case unknown
}

@MainActor
class SavedWordViewModel: ObservableObject {

    @Published var languageData: [String: LanguageEntry] = [:]
    @Published var selectedLanguage: String = "de"  // or "de"
    @Published var selectedTab: WordType = .known
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    
    @Published var userId = Auth.auth().currentUser?.uid


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
    
    func moveToKnown(word: WordPair) {
        guard var saved = languageData[selectedLanguage]?.savedWords else { return }

        saved.unknownWords.removeAll(where: { $0.target == word.target && $0.native == word.native })
        
        // Avoid duplication
        if !saved.knownWords.contains(where: { $0.target == word.target && $0.native == word.native }) {
            saved.knownWords.append(word)
        }
        


        languageData[selectedLanguage]?.savedWords = saved
        
        let docRef = Firestore.firestore().collection("users").document(userId ?? "")
        try? docRef.setData(from: FirestoreLanguageData(languageData: languageData), merge: true)

    }

}
