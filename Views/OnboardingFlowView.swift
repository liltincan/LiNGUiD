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
    @State private var isUsernameAvailable: Bool? = nil
    @State private var isCheckingUsername = false
    @State private var usernameTooLong: Bool = false
    @FocusState private var isUsernameFocused: Bool
    @State private var showGetProPopup = false
    @State private var showCustomAlert = false

    
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
                    }, selectionLimit: 1, selectedLanguages: $selectedNativeLanguages, excludeLanguages: [],
                        onSelectionLimitReached_Native: {
                        withAnimation {
                            showCustomAlert = true
                        }
                        }, isOnNative: true
                    )
                    .layoutPriority(1)
                
                case 1:
                    CustomProgressBar(progress: 0.4, height: 10)
                    .padding(.bottom, 35)
                    
                    ZStack{
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
                        
                        OnboardingPageView(index: 1)
                        //.padding(.bottom, 6)
                    }
                    .padding(.bottom, 31.5)
                
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
                    CustomProgressBar(progress: 0.6, height: 10)
                        .padding(.bottom, 35)

                    ZStack {
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

                        OnboardingPageView(index: 2)
                    }
                    .padding(.bottom, 30)

                    LanguageSelectionView(
                        onContinue: { selected in
                            targetLanguages = selected
                            page += 1
                        },
                        selectionLimit: 1,
                        selectedLanguages: $selectedTargetLanguages,
                        excludeLanguages: nativeLanguages,
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

                
                case 3:
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
                                print("🚀 Saved '\(languageLevels[currentLanguage] ?? "nil")' for \(currentLanguage)")
                                selectPage += 1
                                if selectPage >= targetLanguages.count {
                                    page += 1
                                    selectPage = 0
                                }
                            },
                            onBack: {
                                if selectPage > 0 {
                                    selectPage -= 1
                                } else {
                                    selectPage = 0
                                    page -= 1
                                }
                            }
                        )
                        .padding(.top, 10)
                    }
                
                case 4:
                    CustomProgressBar(progress: 1.0, height: 10)
                    .padding(.bottom, 35)
                    
                    ZStack{
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
                        
                        OnboardingPageView(index: 3)
                        //.padding(.bottom, 10)
                    }
                
                    Spacer(minLength: 75)
                
                    VStack(alignment: .center, spacing: 10) {
                        Text("Username")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .drawingGroup()

                        TextField("Enter your username", text: $username)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color.black)
                            .accentColor(Color.appPrimaryColor)
                            .multilineTextAlignment(.center)
                            .focused($isUsernameFocused) // ← Add this line
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.isUsernameFocused = true
                                }
                            }
                            .onChange(of: username) { newValue in
                                // Allow only letters, numbers, and underscore
                                let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
                                let filtered = newValue
                                    .unicodeScalars
                                    .filter { allowedCharacterSet.contains($0) }
                                    .map { String($0) }
                                    .joined()
                                
                                if filtered.count > 9 {
                                    usernameTooLong = true
                                } else {
                                    usernameTooLong = false
                                }
                                
                                // Limit to max 9 characters
                                let final = String(filtered)

                                if final != username {
                                    username = final
                                }

                                checkUsernameAvailability(final)
                            }
                        if usernameTooLong{
                            Text("Username can't be longer than 9 characters!")
                                .foregroundColor(.red)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.top, 5)
                        }
                        else if let available = isUsernameAvailable, !available {
                            Text("Username is already taken !")
                                .foregroundColor(.red)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.top, 5)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                    .padding(.top, 10)
                    .background(
                        Color.appPrimaryColor
                            .cornerRadius(8)
                    )
                    .padding(.horizontal, 10)
                    
                    if isUsernameFocused{
                        Spacer(minLength: 0)
                    } else{
                        Spacer(minLength: 275)
                    }

                    // ── Continue Button ──
                    Button(action: {
                        page += 1
                        print("Username: \(username)")
                    }) {
                        Text(isCheckingUsername ? "Checking..." : "Continue")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                (isUsernameAvailable == true && !username.isEmpty && !usernameTooLong) ?
                                Color.appPrimaryColor : Color.appSecondaryColor
                            )
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 40)
                    .disabled(username.isEmpty || isUsernameAvailable != true || isCheckingUsername || usernameTooLong)
                
                    
                
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
                        // Use a DispatchGroup to wait for both Firestore operations to complete
                        let dispatchGroup = DispatchGroup()
                        var allSucceeded = true

                        // 1. Save Language Preferences (existing call)
                        dispatchGroup.enter()
                        FirestoreService.shared.updateUserLanguagePreferences(
                            nativeLanguages: selectedNativeLanguages,
                            targetLanguages: selectedTargetLanguages,
                            languageLevels: languageLevels
                        ) { result in
                            switch result {
                            case .success:
                                print("User language preferences saved successfully.")
                            case .failure(let error):
                                print("Error saving language preferences: \(error.localizedDescription)")
                                allSucceeded = false
                            }
                            dispatchGroup.leave()
                        }

                        // 2. Save Country Data (new call)
                        if let country = selectedCountry {
                            dispatchGroup.enter()
                            FirestoreService.shared.updateUserCountry(country: country) { result in
                                switch result {
                                case .success:
                                    print("User country data saved successfully.")
                                case .failure(let error):
                                    print("Error saving country data: \(error.localizedDescription)")
                                    allSucceeded = false
                                }
                                dispatchGroup.leave()
                            }
                        } else {
                            print("No country selected, skipping country data save.")
                        }
                        
                        dispatchGroup.enter()
                        FirestoreService.shared.updateUsername(username: username) { result in
                            switch result {
                            case .success:
                                print("Username saved successfully.")
                            case .failure(let error):
                                print("Error saving username: \(error.localizedDescription)")
                                allSucceeded = false
                            }
                            dispatchGroup.leave()
                        }

                        // Notify when all operations are done
                        dispatchGroup.notify(queue: .main) {
                            if allSucceeded {
                                print("All onboarding data saved successfully!")
                                onComplete() // Complete the onboarding flow only if all operations succeeded
                            } else {
                                print("One or more errors occurred during onboarding data save.")
                                // You might want to show an alert to the user here
                            }
                        }
                    }) {
                        Text("Begin")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appPrimaryColor)
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
        .overlay(
            ZStack {
                if showCustomAlert {
                    // Dimmed blurred background
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation {
                                showCustomAlert = false
                            }
                        }
                    
                    // Alert box
                    VStack(spacing: 20) {
                        Text("Selection Limit Reached")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("You can only select 1 native language")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            withAnimation {
                                showCustomAlert = false
                            }
                        }) {
                            Text("OK")
                                .frame(minWidth: 250)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(Color.appPrimaryColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.appPrimaryColor)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.horizontal, 40)
                    .transition(.slideUpFromBottom)
                }
            }
            .animation(.easeInOut, value: showCustomAlert)
        )
    }
    
    func checkUsernameAvailability(_ name: String) {
        guard !name.isEmpty else {
            isUsernameAvailable = nil
            return
        }

        isCheckingUsername = true
        let db = Firestore.firestore()

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            isUsernameAvailable = nil
            isCheckingUsername = false
            return
        }

        db.collection("users")
            .whereField("userName", isEqualTo: name)
            .getDocuments { snapshot, error in
                isCheckingUsername = false

                if let error = error {
                    print("Error checking username: \(error.localizedDescription)")
                    isUsernameAvailable = nil
                    return
                }

                if let documents = snapshot?.documents {
                    // Check if any other user (not the current user) has this username
                    let takenByAnotherUser = documents.contains { doc in
                        doc.documentID != currentUserID
                    }

                    isUsernameAvailable = !takenByAnotherUser
                } else {
                    isUsernameAvailable = true
                }
            }
    }

}

extension AnyTransition {
    static var slideUpFromBottom: AnyTransition {
        .modifier(
            active: SlideModifier(y: UIScreen.main.bounds.height),
            identity: SlideModifier(y: 0)
        )
    }

    private struct SlideModifier: ViewModifier {
        let y: CGFloat

        func body(content: Content) -> some View {
            content.offset(y: y)
        }
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
                    .fill(Color.appPrimaryColor)
                    .frame(width: geometry.size.width * progress, height: height - 2)
                    .padding(2)
            }
        }
        .frame(height: height)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

//struct OnboardingFlowView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingFlowView {
//            print("Onboarding Complete")
//        }
//    }
//}
