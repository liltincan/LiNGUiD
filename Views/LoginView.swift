import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $vm.email)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $vm.password)
                .textFieldStyle(.roundedBorder)

            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red)
            }

            Button("Log In") {
                Task { await vm.login() }
            }
        }
        .padding()
    }
}
