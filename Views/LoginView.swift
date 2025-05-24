import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    let onSuccess: () -> Void

    var body: some View {
        ZStack{
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("AppLogoPdf").resizable().scaledToFit().padding(.horizontal, 30)
                VStack(spacing: 5){
                    Text("Create an account")
                    .foregroundColor(Color.white)
                    .bold()
                    .font(.system(size: 20))
                    Text("Enter your email to sign up for LiNGUiD")
                    .foregroundColor(Color.white)
                }
                AppTextField(placeholder: "Email", text: $vm.email, keyboardType: UIKeyboardType.emailAddress)
                    
//                TextField("Email", text: $vm.email)
//                    .autocapitalization(.none)
//                    .textFieldStyle(.roundedBorder)
//
//                SecureField("Password", text: $vm.password)
//                    .textFieldStyle(.roundedBorder)

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
                        .cornerRadius(12)
                }
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
