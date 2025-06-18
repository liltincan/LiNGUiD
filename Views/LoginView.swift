import SwiftUI
import _AuthenticationServices_SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()

    @EnvironmentObject var appState: AppState

    let onSuccess: () -> Void

    var body: some View {

        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 50)
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
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(.leading, 15)
                            }
                        }
                        if vm.email != "" || !vm.email.isEmpty {
                            ZStack {
                                AppTextField(
                                    placeholder: "",
                                    text: $vm.password,
                                    isSecureTextEntry: true
                                )

                                if vm.password.isEmpty {
                                    Text("Password")
                                        .foregroundColor(.gray)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading
                                        )
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
                            .background(
                                Color(
                                    red: 124 / 255,
                                    green: 58 / 255,
                                    blue: 237 / 255
                                )
                            )
                            .cornerRadius(10)
                    }

                    divider()

                    AppSocialLoginButton(
                        icon: "GoogleLogo",
                        text: "Continue with Google",
                        action: {
                            if let windowScene = UIApplication.shared
                                .connectedScenes.first as? UIWindowScene,
                                let rootVC = windowScene.windows.first?
                                    .rootViewController
                            {
                                vm.loginWithGoogle(
                                    presenting: rootVC,
                                    appState: appState
                                ) {
                                    onSuccess()
                                }
                            }
                        }
                    )

                    appleSignInOrLoginButton(
                        vm: vm,
                        appState: appState,
                        onSuccess: onSuccess
                    )

                    Spacer()

                    termsAndServicesLink()

                }
                .padding()
            }
            loadingOverlay(isVisible: vm.isLoading)
        }

    }
}

// divider
func divider() -> some View {
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
}

// Apple SignIn/Login Button
func appleSignInOrLoginButton(
    vm: LoginViewModel,
    appState: AppState,
    onSuccess: @escaping () -> Void
) -> some View {
    SignInWithAppleButton(
        .signIn,
        onRequest: { request in
            Task { @MainActor in
                vm.prepareAppleSignInRequest(request)
            }
        },
        onCompletion: { result in
            Task {
                switch result {
                case .success(let authResults):
                    if let appleIDCredential = authResults.credential
                        as? ASAuthorizationAppleIDCredential
                    {
                        await MainActor.run {
                            vm.loginWithApple(
                                credential: appleIDCredential,
                                appState: appState
                            ) {
                                onSuccess()
                            }
                        }
                    }
                case .failure(let error):
                    await MainActor.run {
                        vm.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    )
    .signInWithAppleButtonStyle(.white)  // or .white or .whiteOutline
    .frame(height: 55)
    .cornerRadius(12)

}

// Terms and services
func termsAndServicesLink() -> some View {
    VStack {
        (Text("By clicking continue, you agree to our ")
            .foregroundColor(.white.opacity(0.5))
            + Text("Terms of Service")
            .foregroundColor(.white)
            .fontWeight(.medium)
            + Text(" and ")
            .foregroundColor(.white.opacity(0.5))
            + Text("Privacy Policy")
            .foregroundColor(.white)
            .fontWeight(.medium))
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
    }
}

// Loader
@ViewBuilder
func loadingOverlay(isVisible: Bool) -> some View {
    if isVisible {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(onSuccess: {})
    }
}
