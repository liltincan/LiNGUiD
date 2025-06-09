import SwiftUI

struct OnboardingFlowView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @State private var selectPage = 0
    @State private var targetLanguages: [String] = []
    @State private var nativeLanguages: [String] = []
    @State private var selectedLevel: String? = nil
    @State private var selectedNativeLanguages: Set<String> = []
    @State private var selectedTargetLanguages: Set<String> = []
    @State private var languageLevels: [String: String] = [:]
    
    private let total = 0  // number of pages

    var body: some View {
        VStack {
            
            switch page {
                case 0:
                    OnboardingPageView(index: 0)
                    .padding(.top, 20)
                    
                    LanguageSelectionView(onContinue:{ selected in
                        nativeLanguages = selected
                        let overlap = selectedTargetLanguages.intersection(selected)
                        selectedTargetLanguages.subtract(overlap)
                        targetLanguages.removeAll { overlap.contains($0) }
                        overlap.forEach { languageLevels.removeValue(forKey: $0) }
                        page += 1
                    }, selectionLimit: 3, selectedLanguages: $selectedNativeLanguages, excludeLanguages: [])
                    .padding(.top, -260)
                    .padding(.horizontal, -15)
                    
                    
                case 1:
                    Button(action: {
                        page -= 1
                    }) {
                        Image("Return_Button")
                            .frame(width: 25, height: 25) // Adjust size as needed
                            .padding(.horizontal, 30)
                        }
                        .offset(x: -180, y: 0)
                    OnboardingPageView(index: 1)
                    .padding(.top, -10)
                    .padding(.horizontal, 25)
                
                    LanguageSelectionView(onContinue:{ selected in
                        targetLanguages = selected
                        page += 1
                    }, selectionLimit: 50, selectedLanguages: $selectedTargetLanguages, excludeLanguages: nativeLanguages, onDeselect: { language in
                        languageLevels.removeValue(forKey: language)
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, -275)
                    .padding(.horizontal, -15)
                
                case 2:
                    if selectPage > 0 {
                        Button(action: {
                            selectPage -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25) // Adjust size as needed
                                .padding(.horizontal, 30)
                        }
                        .offset(x: -180, y: 0)
                    }
                    else{
                        Button(action: {
                            page = 1
                            selectPage = 0
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25) // Adjust size as needed
                                .padding(.horizontal, 30)
                        }
                        .offset(x: -180, y: 0)
                    }
                    
                    if selectPage < targetLanguages.count {
                        let currentLanguage = targetLanguages[selectPage]
                        LanguageLevelSelectionView(
                            selectedLevel: Binding(
                                get: { languageLevels[currentLanguage] },
                                set: { languageLevels[currentLanguage] = $0 }
                            ),
                            languageName: currentLanguage,
                            onContinue: {
                                selectPage += 1
                                if selectPage >= targetLanguages.count {
                                    page += 1
                                    selectPage = 0
                                }
                            }
                        )
                    }
                
                case 3:
                    Button(action: {
                        page = 2
                        selectPage = max(targetLanguages.count - 1, 0)
                        
                    }) {
                        Image("Return_Button")
                            .frame(width: 25, height: 25) // Adjust size as needed
                            .padding(.horizontal, 30)
                    }
                    .offset(x: -180, y: 0)
                    OnboardingPageView(index: 2)
                    
                    Button(action: {
                            FirestoreService.shared.updateUserLanguagePreferences(
                            nativeLanguages: selectedNativeLanguages,
                            targetLanguages: selectedTargetLanguages,
                            languageLevels: languageLevels
                        ) { result in
                            switch result {
                            case .success:
                                print("User preferences saved.")
                            case .failure(let error):
                                print("Error saving preferences: \(error.localizedDescription)")
                            }
                            onComplete()
                        }
                    }) {
                        Text("Begin")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .drawingGroup()
                    }
                    .padding(.bottom, 25)
                
                default:
                    EmptyView()
                    
            }
            
            Spacer()
            
            
        }
        .background(Color.black.ignoresSafeArea())
    }
}


struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView {
            print("Onboarding Complete")
        }
    }
}
