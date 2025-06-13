//
//  ChangeLanguageLevelFlow.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 6/13/25.
//

import SwiftUI
import FirebaseFirestore


struct ChangeLanguageLevelFlow: View {
    @State private var languageLevels: [String : String] = [:]
    @State private var currentPage: Int = 0
    @State private var isLoading: Bool = true

    let selectedLanguagesArray: [String]
    let uid: String

    @Environment(\.dismiss) private var dismiss

    init(selectedLanguagesArray: [String], uid: String) {
        self.selectedLanguagesArray = selectedLanguagesArray
        self.uid = uid
    }

    var body: some View {
        ZStack {
            VStack {
                if !isLoading && currentPage < selectedLanguagesArray.count {
                    let currentLanguage = selectedLanguagesArray[currentPage]
                    LanguageLevelSelectionView(
                        selectedLevel: Binding(
                            get: { languageLevels[currentLanguage] ?? "" },
                            set: { languageLevels[currentLanguage] = $0 }
                        ),
                        languageName: currentLanguage,
                        onContinue: {
                            currentPage += 1

                            if currentPage >= selectedLanguagesArray.count {
                                Task {
                                    await saveLanguageLevels()
                                }
                                dismiss()
                            }
                        }
                    )
                } else if !isLoading && currentPage >= selectedLanguagesArray.count {
                    ProgressView()
                } else {
                    ProgressView("Loading existing levels...")
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Change Language Level")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isLoading {
                    Task {
                        await fetchExistingLanguageLevels()
                        await MainActor.run {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }

    private func fetchExistingLanguageLevels() async {
        let db = Firestore.firestore()
        do {
            let docRef = db.collection("users").document(uid)
            let document = try await docRef.getDocument()

            if let data = document.data(),
               let languagesData = data["languagesData"] as? [String: [String: Any]] {

                let comprehensionLevelsMap: [Int: String] = [
                    1: "Just Starting",
                    2: "Beginner",
                    3: "Intermediate",
                    4: "Advanced",
                    5: "Expert"
                ]

                var loadedLevels: [String: String] = [:]
                for (lang, details) in languagesData {
                    if selectedLanguagesArray.contains(lang) {
                        if let level = details["comprehensionLevel"] as? Int {
                            loadedLevels[lang] = comprehensionLevelsMap[level] ?? "Just Starting"
                        }
                    }
                }
                await MainActor.run {
                    self.languageLevels = loadedLevels
                }
            }
        } catch {
            print("Error fetching existing language levels: \(error.localizedDescription)")
        }
    }

    private func saveLanguageLevels() async {
        let db = FirebaseFirestore.Firestore.firestore()
        var updates: [String: Any] = [:]
        let levelsDictionary: [String: Int] = [
            "Just Starting": 1,
            "Beginner": 2,
            "Intermediate": 3,
            "Advanced": 4,
            "Expert": 5
        ]

        for language in selectedLanguagesArray {
            if let selectedLevel = languageLevels[language] {
                let comprehensionLevel = levelsDictionary[selectedLevel] ?? 1

                updates["languagesData.\(language).comprehensionLevel"] = comprehensionLevel
            }
        }
        
        guard !updates.isEmpty else {
            return
        }

        do {
            try await db.collection("users").document(uid).updateData(updates)
        } catch {
            print("Error updating language levels in Firestore: \(error.localizedDescription)")
        }
    }
}
