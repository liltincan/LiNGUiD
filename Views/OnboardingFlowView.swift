import SwiftUI
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

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
    @State private var selectedCountry: String? = nil
    @State private var username: String = ""
    @State private var locationManager = CLLocationManager()
    
    
    private let total = 0  // number of pages

    var body: some View {
        VStack {
            
            switch page {
                case 0:
                    CustomProgressBar(progress: 0.2, height: 10)
                    .padding(.bottom, 35)
                    
                    OnboardingPageView(index: 0)
                    .padding(.bottom, 10)
                    
                    LanguageSelectionView(onContinue:{ selected in
                        nativeLanguages = selected
                        let overlap = selectedTargetLanguages.intersection(selected)
                        selectedTargetLanguages.subtract(overlap)
                        targetLanguages.removeAll { overlap.contains($0) }
                        overlap.forEach { languageLevels.removeValue(forKey: $0) }
                        locationManager.requestWhenInUseAuthorization()
                        page += 1
                    }, selectionLimit: 3, selectedLanguages: $selectedNativeLanguages, excludeLanguages: [])
                    .layoutPriority(1)
                
                case 1:
                    HStack {
                        Button(action: {
                            page -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                    
                
                    CustomProgressBar(progress: 0.4, height: 10)
                    .padding(.bottom, 25)
                
                    OnboardingPageView(index: 1)
                    .padding(.bottom, 6)
                
                    CountrySelectionView(
                        selectedCountry: $selectedCountry,
                        onContinue: {
                            print("User picked country:", selectedCountry!)
                            page += 1  // move to next page
                        }
                    )
                    .padding()
                    .layoutPriority(1)
                
                    
                    
                case 2:
                    HStack {
                        Button(action: {
                            page -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                    
                    CustomProgressBar(progress: 0.6, height: 10)
                    .padding(.bottom, 25)
                    
                    OnboardingPageView(index: 2)
                    .padding(.bottom, 7.5)

                
                    LanguageSelectionView(onContinue:{ selected in
                        targetLanguages = selected
                        page += 1
                    }, selectionLimit: 50, selectedLanguages: $selectedTargetLanguages, excludeLanguages: nativeLanguages, onDeselect: { language in
                        languageLevels.removeValue(forKey: language)
                    })
                    .layoutPriority(1)
                
                case 3:
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
                    }
                    else{
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
                    let step = 0.2 / Double(targetLanguages.count)
                    let progress = baseProgress + (Double(selectPage + 1) * step)

                    CustomProgressBar(progress: progress, height: 10)
                    .padding(.bottom, 10)

                
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
                        .padding(.top, 10)
                    }
                
                case 4:
                    HStack {
                        Button(action: {
                            page -= 1
                            selectPage = max(targetLanguages.count - 1, 0)
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                
                    CustomProgressBar(progress: 1.0, height: 10)
                    .padding(.bottom, 25)
                    
                    OnboardingPageView(index: 3)
                    //.padding(.bottom, 10)
                
                    VStack(alignment: .center, spacing: 10) {
                        Text("Username")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .drawingGroup()

                        TextField("Enter your username", text: $username)
                            .padding()
                            .background(Color.white)
                            //.cornerRadius(8)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                    .padding(.top, 10)
                    .background(
                        Color(red: 124/255, green: 58/255, blue: 237/255)
                            .cornerRadius(8)
                    )
                    .padding(.horizontal, 10)

                    Spacer(minLength: 275)

                    // ── Continue Button ──
                    Button(action: {
                        page += 1
                        print("Username: \(username)")
                    }) {
                        Text("Continue")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(username.isEmpty ? Color(red: 62/255, green: 29/255, blue: 119/255) : Color(red: 124/255, green: 58/255, blue: 237/255))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 40)
                    .disabled(username.isEmpty) // prevent tap when empty
                
                    
                
                case 5:
                    HStack {
                        Button(action: {
                            page -= 1
                        }) {
                            Image("Return_Button")
                                .frame(width: 25, height: 25)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                
                    OnboardingPageView(index: 4)
                    
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
            
            //Spacer()
            
            
        }
        .background(Color.black.ignoresSafeArea())
    }
}


struct CustomProgressBar: View {
    var progress: Double // from 0.0 to 1.0
    var height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white)
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(red: 124/255, green: 58/255, blue: 237/255))
                    .frame(width: geometry.size.width * progress, height: height - 2)
                    .padding(2)
            }
        }
        .frame(height: height)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView {
            print("Onboarding Complete")
        }
    }
}
