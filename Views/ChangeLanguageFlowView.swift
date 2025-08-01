import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChangeLanguageFlowView: View {
    var uid: String
    var preselectedLanguageCodes: Set<String>? // New optional parameter for short codes
    @State private var selectedNativeLanguages: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedLanguagesArray: [String] = []
    @State private var languageLevels: [String: String] = [:]
    @State private var page = 0 // Start at 0 for language selection
    @State private var selectPage = 0 // For level selection pagination
    @State private var nativeLanguageNamesToExclude: Set<String> = []
    @State private var existingLanguages: Set<String> = []
    @State private var showGetProPopup = false
    @StateObject private var proVM = ProStatusViewModel()

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
        //self.existingLanguages = existingLanguages
        self.uid = uid
        self.preselectedLanguageCodes = preselectedLanguageCodes
        self._selectedNativeLanguages = State(initialValue: selectedNativeLanguages)
    }
    
    var body: some View {
        VStack {
            switch page {
            case 0:
                // Language Selection (mirrors onboarding case 2)
                CustomProgressBar(progress: 0.5, height: 10)
                    .padding(.bottom, 25)
                
                OnboardingPageView(index: 2)
                    .padding(.bottom, 7.5)
                
                if proVM.isPro{
                    LanguageSelectionView(
                        onContinue: { selected in
                            let selectedSet = Set(selected)
                            let newLanguages = selectedSet.filter { !existingLanguages.contains($0) }
                            
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
                        selectionLimit: 49,
                        selectedLanguages: $selectedLanguages,
                        excludeLanguages: Array(selectedNativeLanguages),
                        onDeselect: { language in
                            languageLevels.removeValue(forKey: language)
                        }
                    )
                    .layoutPriority(1)
                } else{
                    LanguageSelectionView(
                        onContinue: { selected in
                            let selectedSet = Set(selected)
                            let newLanguages = selectedSet.filter { !existingLanguages.contains($0) }
                            
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
                        selectionLimit: 1,
                        selectedLanguages: $selectedLanguages,
                        excludeLanguages: Array(selectedNativeLanguages),
                        onDeselect: { language in
                            languageLevels.removeValue(forKey: language)
                        },
                        onSelectionLimitReached_Foreign: {
                            withAnimation {
                                showGetProPopup = true
                            }
                        }
                    )
                    .layoutPriority(1)
                }
                
            case 1:
                // Language Level Selection (mirrors onboarding case 3)
//                if selectPage > 0 {
//                    HStack {
//                        Button(action: {
//                            selectPage -= 1
//                        }) {
//                            Image("Return_Button")
//                                .frame(width: 25, height: 25)
//                                .padding(.leading, 10)
//                        }
//                        Spacer()
//                    }
//                } else {
//                    HStack {
//                        Button(action: {
//                            selectPage = 0
//                            page -= 1
//                        }) {
//                            Image("Return_Button")
//                                .frame(width: 25, height: 25)
//                                .padding(.leading, 10)
//                        }
//                        Spacer()
//                    }
//                }
                
                let baseProgress = 0.5
                let step = (1.0 - baseProgress) / Double(selectedLanguagesArray.count)
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
                        },
                        fromSettings: true
                    )
                    .padding(.top, 10)
                }
                
            default:
                EmptyView()
            }
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                proVM.startListening(uid: uid)
            }
        }
        .onDisappear {
            proVM.stopListening()
        }
        .onAppear {
            fetchUserLanguageLists(for: uid) { nativeCodes, targetCodes in
                let nativeNames = convertLanguageCodesToNames(nativeCodes)
                let targetNames = convertLanguageCodesToNames(targetCodes)
                
                nativeLanguageNamesToExclude = nativeNames
                selectedNativeLanguages = nativeNames
                selectedLanguages = targetNames
                selectedLanguagesArray = []

                // ✅ Assign this so comparison works correctly
                existingLanguages = targetNames
            }
        }
        .overlay(
            ZStack {
                if showGetProPopup {
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation {
                                showGetProPopup = false
                            }
                        }

                    VStack {
                        Spacer()

                        GetProView()
                            .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.5)
                            .padding(.horizontal, 20)
                            .background(
                                Color(red: 22/255, green: 0/255, blue: 46/255)
                                    .cornerRadius(24)
                            )

                        Spacer()
                    }
                    .transition(.slideUpFromBottom)
                }
            }
            .animation(.easeInOut, value: showGetProPopup)
        )
        .background(Color.black.ignoresSafeArea())
    }
    
    func fetchIsProStatus(uid: String) async -> Bool {
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            let data = document.data()
            let isPro = data?["isPro"] as? Bool ?? false
            print("✅ Fetched isPro status: \(isPro)")
            return isPro
        } catch {
            print("Error fetching isPro status: \(error.localizedDescription)")
            return false
        }
    }
    
    private func fetchUserLanguageLists(for uid: String, completion: @escaping (Set<String>, Set<String>) -> Void) {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid)
        
        docRef.getDocument { document, error in
            if let document = document, document.exists,
               let data = document.data() {
                
                let nativeCodes = Set((data["nativeLanguageList"] as? [String]) ?? [])
                let targetCodes = Set((data["targetLanguageList"] as? [String]) ?? [])
                completion(nativeCodes, targetCodes)
            } else {
                print("❌ Failed to fetch language lists: \(error?.localizedDescription ?? "Unknown error")")
                completion([], [])
            }
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

//Just in case return button is needed in the future
// Language Level Selection (mirrors onboarding case 3)
//                if selectPage > 0 {
//                    HStack {
//                        Button(action: {
//                            selectPage -= 1
//                        }) {
//                            Image("Return_Button")
//                                .frame(width: 25, height: 25)
//                                .padding(.leading, 10)
//                        }
//                        Spacer()
//                    }
//                } else {
//                    HStack {
//                        Button(action: {
//                            selectPage = 0
//                            page -= 1
//                        }) {
//                            Image("Return_Button")
//                                .frame(width: 25, height: 25)
//                                .padding(.leading, 10)
//                        }
//                        Spacer()
//                    }
//                }
