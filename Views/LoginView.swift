import SwiftUI
import _AuthenticationServices_SwiftUI

private enum LegalSheet: Identifiable {
    case terms, privacy
    var id: Int { hashValue }
}

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppLogoPdf")
                    .scaledToFit()
                    .padding(30)

                VStack(spacing: 5) {
                    Text("Create an account")
                        .foregroundColor(.white)
                        .bold()
                        .font(.system(size: 20))

                    Text("Enter your email to sign up for LiNGUiD")
                        .foregroundColor(.white)
                }

                VStack(spacing: 20) {
                    ZStack {
                        AppTextField(
                            placeholder: "",
                            text: $vm.email,
                            keyboardType: .emailAddress
                        )

                        if vm.email.isEmpty {
                            Text("Email")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 15)
                        }
                    }
                    if(vm.email != "" || !vm.email.isEmpty){
                        ZStack {
                            AppTextField(
                                placeholder: "",
                                text: $vm.password,
                                isSecureTextEntry: true
                            )

                            if vm.password.isEmpty {
                                Text("Password")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 15)
                            }
                        }
                    }
                    

                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    Task {
                        if await vm.login(appState: appState) {
                            onSuccess()
                        }
                    }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                        .cornerRadius(10)
                }

                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1)

                    Text("or")
                        .foregroundColor(Color.white.opacity(0.5))

                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1)
                }

                AppSocialLoginButton(
                    icon: "GoogleLogo",
                    text: "Continue with Google",
                    action: {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            vm.loginWithGoogle(presenting: rootVC, appState: appState) {
                                onSuccess()
                            }
                        }
                    }
                )
                
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        vm.prepareAppleSignInRequest(request)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                vm.loginWithApple(credential: credential, appState: appState) {
                                    onSuccess()
                                }
                            }
                        case .failure(let error):
                            vm.errorMessage = error.localizedDescription
                        }
                    }
                )

                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 55)
                .cornerRadius(12)



                Text("By clicking continue, you agree to our [Terms of Service](https://learnwithlinguid.com/terms-of-service) and [Privacy Policy](https://learnwithlinguid.com/privacy-policy)")
                    .foregroundColor(.white.opacity(0.6))
                    .tint(.white)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
            }
            .padding()
            
            // Loading overlay - only essential addition
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(onSuccess: {})
    }
}
