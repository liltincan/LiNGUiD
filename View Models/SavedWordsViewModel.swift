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
    @Published var selectedLanguage: String = "de"
    @Published var selectedTab: WordType = .known
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func fetchLanguageData(userId: String?) async {
        guard let uid = userId else {
            errorMessage = "User not signed in."
            return
        }

        let docRef = db.collection("users").document(uid)

        do {
            let snapshot = try await docRef.getDocument()
            let data = try snapshot.data(as: FirestoreLanguageData.self)
            self.languageData = data.languageData
        } catch {
            self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
        }
    }

    func moveToKnown(word: WordPair, userId: String?) {
        guard var saved = languageData[selectedLanguage]?.savedWords else { return }
        guard let uid = userId else { return }

        saved.unknownWords.removeAll { $0.target == word.target && $0.native == word.native }

        if !saved.knownWords.contains(where: { $0.target == word.target && $0.native == word.native }) {
            saved.knownWords.append(word)
        }

        languageData[selectedLanguage]?.savedWords = saved

        let docRef = db.collection("users").document(uid)
        do {
            try docRef.setData(from: FirestoreLanguageData(languageData: languageData), merge: true)
        } catch {
            print("Failed to update words: \(error.localizedDescription)")
        }
    }
}
