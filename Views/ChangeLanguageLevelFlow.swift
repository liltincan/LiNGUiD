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

    var selectedLanguagesArray: [String]
    let uid: String
    
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
    
    init(selectedLanguagesArray: [String], uid: String) {
        self.selectedLanguagesArray = selectedLanguagesArray
        self.uid = uid
        for (index, lang) in selectedLanguagesArray.enumerated() {
            
            if let key = languageCodes.someKey(forValue: lang) {
                self.selectedLanguagesArray[index] = key
            }
        }
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
                let lang = languageCodes[language] ?? ""
                updates["languagesData.\(lang).comprehensionLevel"] = comprehensionLevel
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
