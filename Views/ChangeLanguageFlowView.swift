import SwiftUI
import FirebaseFirestore

struct ChangeLanguageFlowView: View {
    var existingLanguages: Set<String>?
    var uid: String
    var preselectedLanguageCodes: Set<String>? // New optional parameter for short codes
    @State private var selectedNativeLanguages: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedLanguagesArray: [String] = []
    @State private var languageLevels: [String: String] = [:]
    @State private var page = 0 // Start at 0 for language selection
    @State private var selectPage = 0 // For level selection pagination
    
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
    
    // Add initializer to accept selectedNativeLanguages parameter
    init(existingLanguages: Set<String>? = nil,
         uid: String,
         preselectedLanguageCodes: Set<String>? = nil,
         selectedNativeLanguages: Set<String>) {
        self.existingLanguages = existingLanguages
        self.uid = uid
        self.preselectedLanguageCodes = preselectedLanguageCodes
        self._selectedNativeLanguages = State(initialValue: selectedNativeLanguages)
    }
    
    var body: some View {
        VStack {
            switch page {
            case 0:
                // Language Selection (mirrors onboarding case 2)
                CustomProgressBar(progress: 0.6, height: 10)
                    .padding(.bottom, 25)
                
                OnboardingPageView(index: 2)
                    .padding(.bottom, 7.5)
                
                LanguageSelectionView(
                    onContinue: { selected in
                        let selectedSet = Set(selected)
                        let newLanguages = selectedSet.filter { !(existingLanguages ?? []).contains($0) }
                        
                        selectedLanguages = selectedSet
                        selectedLanguagesArray = Array(newLanguages)
                        
                        if newLanguages.isEmpty {
                            // No new languages, just save current selection and dismiss
                            Task {
                                await saveLanguages()
                            }
                            dismiss()
                        } else {
                            // New languages detected, proceed to level selection
                            page = 1
                        }
                    },
                    selectionLimit: 50,
                    selectedLanguages: $selectedLanguages,
                    excludeLanguages: [],
                    onDeselect: { language in
                        languageLevels.removeValue(forKey: language)
                    }
                )
                .layoutPriority(1)
                
            case 1:
                // Language Level Selection (mirrors onboarding case 3)
                if selectPage > 0 {
                    HStack {
                        Button(action: {
                            selectPage -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                } else {
                    HStack {
                        Button(action: {
                            selectPage = 0
                            page -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                }
                
                let baseProgress = 0.6
                let step = 0.2 / Double(selectedLanguagesArray.count)
                let progress = baseProgress + (Double(selectPage + 1) * step)
                
                CustomProgressBar(progress: progress, height: 10)
                    .padding(.bottom, 10)
                
                if selectPage < selectedLanguagesArray.count {
                    let currentLanguage = selectedLanguagesArray[selectPage]
                    
                    LanguageLevelSelectionView(
                        selectedLevel: Binding(
                            get: { languageLevels[currentLanguage] },
                            set: { languageLevels[currentLanguage] = $0 }
                        ),
                        languageName: currentLanguage,
                        onContinue: {
                            print("🚀 Saved '\(languageLevels[currentLanguage] ?? "nil")' for \(currentLanguage)")
                            selectPage += 1
                            if selectPage >= selectedLanguagesArray.count {
                                // Finished all level selections, save and dismiss
                                Task {
                                    await saveLanguages()
                                }
                                dismiss()
                            }
                        }
                    )
                    .padding(.top, 10)
                }
                
            default:
                EmptyView()
            }
        }
        .onAppear {
            // Convert preselected language codes to full names if provided
            if let preselectedCodes = preselectedLanguageCodes {
                let convertedLanguages = convertLanguageCodesToNames(preselectedCodes)
                selectedLanguages = (existingLanguages ?? []).union(convertedLanguages)
            } else {
                selectedLanguages = existingLanguages ?? []
            }
            let convertedNativeLanguages = convertLanguageCodesToNames(selectedNativeLanguages)
            selectedNativeLanguages = convertedNativeLanguages
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // Helper function to convert language codes to full names
    private func convertLanguageCodesToNames(_ codes: Set<String>) -> Set<String> {
        var languageNames: Set<String> = []
        
        for code in codes {
            if let languageName = languageCodes.someKey(forValue: code) {
                languageNames.insert(languageName)
            }
        }
        
        return languageNames
    }
    
    private func saveLanguages() async {
        // Get existing native languages (you may need to fetch these from Firestore)
        // For now, assuming we're only updating target languages
        let selectedTargetLanguages = selectedLanguages
        await withCheckedContinuation { continuation in
            FirestoreService.shared.updateUserLanguagePreferences(
                nativeLanguages: selectedNativeLanguages,
                targetLanguages: selectedTargetLanguages,
                languageLevels: languageLevels
            ) { result in
                switch result {
                case .success:
                    print("User language preferences updated successfully.")
                case .failure(let error):
                    print("Error updating language preferences: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
}


extension Dictionary where Value: Equatable {
    func someKey(forValue val: Value) -> Key? {
        return first(where: { $1 == val })?.key
    }
}
