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
import SwiftUICore

enum WordType {
    case known
    case unknown
}

@MainActor
class SavedWordViewModel: ObservableObject {
    @Published var savedWords: WordLists?
    @Published var selectedLanguage: String = "de"
    @Published var selectedTab: WordType = .known
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
        private let userSession: UserSessionViewModel

        init(userSession: UserSessionViewModel) {
            self.userSession = userSession
        }
    
    


    func fetchLanguageData() async {
        await userSession.refreshUser()
        if let languageKey = userSession.currentUser?.targetLanguage,
           let savedWords = userSession.currentUser?.languagesData?[languageKey]?.savedWords {
            self.savedWords = savedWords
        } else {
            self.savedWords = nil
            self.errorMessage = "Failed to fetch saved words for selected language."
        }

    }

    func moveToKnown(word: WordPair, userId: String) {
        
        let languageKey = userSession.currentUser?.targetLanguage ?? ""
           
        guard var saved = savedWords else { return }
           
        saved.unknownWords.removeAll { $0.target == word.target && $0.native == word.native }

        if !saved.knownWords.contains(where: { $0.target == word.target && $0.native == word.native }) {
            saved.knownWords.append(word)
        }


        savedWords = saved

        do {
            let known = saved.knownWords.map { WordPair(target: $0.target, native: $0.native) }
            let unknown = saved.unknownWords.map { WordPair(target: $0.target, native: $0.native) }

            let savedWords = WordLists(knownWords: known, unknownWords: unknown)
            let languageData = LanguagesData(savedWords: savedWords)
            let patch = FirestoreUserPatch(languagesData: [languageKey: languageData])

            let docRef = Firestore.firestore().collection("users").document(userId)
            try docRef.setData(from: patch, merge: true)



        } catch {
            print("🔥 Failed to encode savedWords: \(error.localizedDescription)")
        }

    }
}
