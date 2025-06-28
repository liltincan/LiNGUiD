import SwiftUI
import FirebaseFirestore

struct ChangeLanguageFlowView: View {
    var existingLanguages: Set<String>?
    var uid: String
    var preselectedLanguageCodes: Set<String>? // New optional parameter for short codes
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedLanguagesArray: [String] = []
    @State private var languageLevels: [String: String] = [:]
    @State private var currentPage = 0
    @State private var isSelectingLevels = false
    
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
    
    var body: some View {
        VStack {
            if !isSelectingLevels {
                OnboardingPageView(index: 1)
                
                LanguageSelectionView(
                    onContinue: { selectedArray in
                        let selectedSet = Set(selectedArray)

                        let newLanguages = selectedSet.filter { !(existingLanguages ?? []).contains($0) }
                        
                        selectedLanguages = selectedSet
                        selectedLanguagesArray = Array(newLanguages)
                        
                        if newLanguages.isEmpty {
                            if selectedSet.isSubset(of: existingLanguages ?? []) {
                                Task {
                                    await saveLanguages()
                                }
                                dismiss()
                            } else {
                                Task {
                                    await saveLanguages()
                                }
                                dismiss()
                            }
                        } else {
                            isSelectingLevels = true
                        }
                    },
                    selectionLimit: 5,
                    selectedLanguages: $selectedLanguages
                )
                .padding(.top, -250)
                .padding(.horizontal, -15)
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
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Change Language")
        .navigationBarTitleDisplayMode(.inline)
        
        if currentPage < selectedLanguagesArray.count {
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
                        isSelectingLevels = false
                        Task {
                            await saveLanguages()
                        }
                        dismiss()
                    }
                }
            )
        }
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
        // Assuming native languages are not being changed in this flow
        // You may need to adjust this based on your app's logic
        let selectedNativeLanguages: [String] = [] // Add your native languages logic here
        let selectedTargetLanguages = Array(selectedLanguages)
        
        await withCheckedContinuation { continuation in
            FirestoreService.shared.updateUserLanguagePreferences(
                nativeLanguages: Set(selectedNativeLanguages),
                targetLanguages: Set(selectedTargetLanguages),
                languageLevels: languageLevels
            ) { result in
                switch result {
                case .success:
                    print("User preferences saved.")
                case .failure(let error):
                    print("Error saving preferences: \(error.localizedDescription)")
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
