import SwiftUI
import FirebaseFirestore

struct ChangeLanguageFlowView: View {
    var existingLanguages: Set<String>
    var uid: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedLanguagesArray: [String] = []
    @State private var languageLevels: [String: String] = [:]
    @State private var currentPage = 0
    @State private var isSelectingLevels = false
    
    var body: some View {
        VStack {
            if !isSelectingLevels {
                OnboardingPageView(index: 1)
                
                LanguageSelectionView(
                    onContinue: { selectedArray in
                        let selectedSet = Set(selectedArray)

                        let newLanguages = selectedSet.filter { !existingLanguages.contains($0) }
                        
                        selectedLanguages = selectedSet
                        selectedLanguagesArray = Array(newLanguages)
                        
                        if newLanguages.isEmpty {
                            if selectedSet.isSubset(of: existingLanguages) {
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
            selectedLanguages = existingLanguages
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
    
    private func saveLanguages() async {
        let db = Firestore.firestore()
        
        var languagesDataUpdates: [String: Any] = [:]
        
        let languagesToRemove = existingLanguages.subtracting(selectedLanguages)
        for language in languagesToRemove {
            languagesDataUpdates[language] = FieldValue.delete()
        }
        
        for language in selectedLanguages {
            if !existingLanguages.contains(language) {
                let level = languageLevels[language] ?? ""
                let levelsDictionary: [String: Int] = ["Just Starting": 1, "Beginner": 2, "Intermediate": 3, "Advanced": 4, "Expert": 5]
                
                let languageDetails: [String: Any] = [
                    "comprehensionLevel": levelsDictionary[level] ?? 1,
                    "timestamp": Timestamp(date: Date()),
                ]
                languagesDataUpdates[language] = languageDetails
            }
        }
        
        guard !languagesDataUpdates.isEmpty else {
            return
        }
        
        let dataToSave: [String: Any] = [
            "languagesData": languagesDataUpdates
        ]
        
        do {
            try await db.collection("users").document(uid).setData(dataToSave, merge: true)
        } catch {
            print("Error saving profile data to Firestore: \(error.localizedDescription)")
        }
    }
}
