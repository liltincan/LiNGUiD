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
    @State private var currentSelectedLevel: String? = nil


    let uid: String
    @State private var filteredLanguagesArray: [String] = [] // language names

    @Environment(\.dismiss) private var dismiss
    
    let languageCodes: [String: String] = [
          "Arabic": "ar", "Chinese": "zh", "English": "en", "French": "fr", "German": "de",
          "Italian": "it", "Portuguese": "pt", "Russian": "ru", "Spanish": "es",
          "Afrikaans": "af", "Armenian": "hy", "Azerbaijani": "az", "Belarusian": "be",
          "Bosnian": "bs", "Bulgarian": "bg", "Catalan": "ca", "Croatian": "hr", "Czech": "cs",
          "Danish": "da", "Dutch": "nl", "Estonian": "et", "Finnish": "fi", "Galician": "gl",
          "Greek": "el", "Hebrew": "he", "Hindi": "hi", "Hungarian": "hu", "Icelandic": "is",
          "Indonesian": "id", "Japanese": "ja", "Kannada": "kn", "Kazakh": "kk", "Korean": "ko",
          "Latvian": "lv", "Lithuanian": "lt", "Macedonian": "mk", "Malay": "ms", "Maori": "mi",
          "Marathi": "mr", "Nepali": "ne", "Norwegian": "no", "Persian": "fa", "Polish": "pl",
          "Romanian": "ro", "Serbian": "sr", "Slovak": "sk", "Slovenian": "sl", "Swahili": "sw",
          "Swedish": "sv", "Tagalog": "tl", "Tamil": "ta", "Thai": "th", "Turkish": "tr",
          "Ukrainian": "uk", "Urdu": "ur", "Vietnamese": "vi", "Welsh": "cy"
    ]
    
    init(uid: String) {
        self.uid = uid
    }

    
    var body: some View {
        ZStack {
            VStack {
                if !isLoading && currentPage < filteredLanguagesArray.count {
                    let progress = Double(currentPage + 1) / Double(filteredLanguagesArray.count)
                    
                    CustomProgressBar(progress: progress, height: 10)
                        .padding(.bottom, 10)
                    
                    let currentLanguage = filteredLanguagesArray[currentPage]
                    LanguageLevelSelectionView(
                        selectedLevel: $currentSelectedLevel,
                        languageName: currentLanguage,
                        onContinue: {
                            languageLevels[currentLanguage] = currentSelectedLevel
                            print("🚀 Saved '\(currentSelectedLevel ?? "nil")' for \(currentLanguage)")
                            //currentSelectedLevel = nil // Clear for next screen
                            currentPage += 1
                            if currentPage >= filteredLanguagesArray.count {
                                Task {
                                    await saveLanguageLevels()
                                }
                                dismiss()
                            }
                        },
                        fromSettings: true
                    )
                    .id(currentLanguage) // 💡 Forces reinit when language changes
                    .onAppear {
                        currentSelectedLevel = languageLevels[currentLanguage]
                    }
                    .onChange(of: currentPage) { newPage in
                        if newPage < filteredLanguagesArray.count {
                            let currentLanguage = filteredLanguagesArray[newPage]
                            currentSelectedLevel = languageLevels[currentLanguage]
                        }
                    }

                } else if !isLoading && currentPage >= filteredLanguagesArray.count {
                    ProgressView()
                } else {
                    ProgressView("Loading existing levels...")
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            .background(Color.black.ignoresSafeArea())
            //.navigationTitle("Change Language Level")
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

            if let data = document.data() {
                let allLanguagesData = data["languagesData"] as? [String: [String: Any]] ?? [:]
                let targetLanguageCodes = data["targetLanguageList"] as? [String] ?? []
                let filteredData = allLanguagesData.filter { targetLanguageCodes.contains($0.key) }

                let comprehensionLevelsMap: [Int: String] = [
                    1: "Just Starting",
                    2: "Beginner",
                    3: "Intermediate",
                    4: "Advanced",
                    5: "Expert"
                ]

                var loadedLevels: [String: String] = [:]
                var languageNames: [String] = []

                for langCode in targetLanguageCodes {
                    if let details = filteredData[langCode],
                       let level = details["comprehensionLevel"] as? Int {
                        if let langName = languageCodes.first(where: { $0.value == langCode })?.key {
                            loadedLevels[langName] = comprehensionLevelsMap[level] ?? "Just Starting"
                            languageNames.append(langName)
                        }
                    }
                }

                await MainActor.run {
                    self.languageLevels = loadedLevels
                    self.filteredLanguagesArray = languageNames
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

        for language in filteredLanguagesArray {
            if let selectedLevel = languageLevels[language] {
                let comprehensionLevel = levelsDictionary[selectedLevel] ?? 1
                let langCode = languageCodes[language] ?? ""
                updates["languagesData.\(langCode).comprehensionLevel"] = comprehensionLevel
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
