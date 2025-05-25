import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    let onSuccess: () -> Void

    var body: some View {
        ZStack{
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("AppLogoPdf").resizable().scaledToFit().padding(30)
                VStack(spacing: 5){
                    Text("Create an account")
                    .foregroundColor(Color.white)
                    .bold()
                    .font(.system(size: 20))
                    Text("Enter your email to sign up for LiNGUiD")
                    .foregroundColor(Color.white)
                }
                AppTextField(placeholder: "Email", text: $vm.email, keyboardType: UIKeyboardType.emailAddress)

                if let error = vm.errorMessage {
                    Text(error).foregroundColor(.red)
                }
                
                Button {
                    Task {
                        if await vm.login() {
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
                
                HStack{
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1)
                    
                    Text("or")
                        .foregroundColor(Color.white.opacity(0.5))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1)
                }
                
                AppSocialLoginButton(icon: "GoogleLogo", text: "Continue with Google", action: {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        vm.loginWithGoogle(presenting: rootVC){
                            onSuccess()
                        }
                    }
                })
                
                AppSocialLoginButton(icon: "AppleLogo", text: "Continue with Apple", action: {})
                
                VStack{
                    Text("By clicking continue, you agree to our ")
                        .foregroundColor(Color.white.opacity(0.5))
                    + Text("Terms of Service")
                        .foregroundColor(Color.white)
                        .fontWeight(.medium)
                    + Text(" and ")
                        .foregroundColor(Color.white.opacity(0.5))
                    + Text("Privacy Policy")
                        .foregroundColor(Color.white)
                        .fontWeight(.medium)
                }
                .multilineTextAlignment(.center)
                .padding(.vertical,10)
                
            }
            .padding()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(onSuccess: {})
    }
}
