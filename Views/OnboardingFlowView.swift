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
                    
                    LanguageSelectionView(onContinue:{ selected in
                        nativeLanguages = selected
                        page += 1
                    }, selectionLimit: 3, selectedLanguages: $selectedNativeLanguages, excludeLanguages: [])
                    .padding(.top, -250)
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
                
                    LanguageSelectionView(onContinue:{ selected in
                        targetLanguages = selected
                        page += 1
                    }, selectionLimit: 50, selectedLanguages: $selectedTargetLanguages, excludeLanguages: nativeLanguages)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, -250)
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
                            onComplete()
                    }) {
                        Text("Begin")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                    .padding(.horizontal, 10)
                
                default:
                    EmptyView()
                    Button(action: {
                            page += 1
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                    .padding(.horizontal, 10)
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
