import SwiftUI

struct ChangePasswordView: View {
    @StateObject private var viewModel = ChangePasswordViewModel()
    @StateObject private var loginVM = LoginViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    private let brandColor = Color(red: 124/255, green: 58/255, blue: 237/255)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                
                if !viewModel.isReauthenticated {
                    reauthenticationSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    updatePasswordSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                messageView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isReauthenticated)
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            setupView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Change Password")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Update your password securely")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var reauthenticationSection: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Step 1 of 2", subtitle: "Verify your identity")
            
            if viewModel.userIsGoogleUser {
                googleReauthContent
            } else {
                emailPasswordReauthContent
            }
        }
        .simpleCardStyle()
    }
    
    private var googleReauthContent: some View {
        VStack(spacing: 16) {
            Text("You are signed in with Google. Please reauthenticate to continue.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            SimpleGoogleButton {
                viewModel.googleReauth(loginVM: loginVM)
            }
        }
    }
    
    private var emailPasswordReauthContent: some View {
        VStack(spacing: 16) {
            Text("Please reauthenticate with your current email and password.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            VStack(spacing: 14) {
                SimpleTextField(
                    placeholder: "Current Email",
                    text: $loginVM.email,
                    keyboardType: .emailAddress,
                    brandColor: brandColor
                )

                SimpleTextField(
                    placeholder: "Current Password",
                    text: $loginVM.password,
                    isSecure: true,
                    brandColor: brandColor
                )
            }

            SimpleButton(
                title: "Verify Identity",
                isLoading: viewModel.isLoading,
                backgroundColor: brandColor,
                isDisabled: viewModel.isLoading || loginVM.email.isEmpty || loginVM.password.isEmpty
            ) {
                viewModel.emailPasswordReauth(loginVM: loginVM)
            }
        }
    }

    private var updatePasswordSection: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Step 2 of 2", subtitle: "Set your new password")
            
            VStack(spacing: 16) {
                Text("Enter your new password and confirm it below.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                VStack(spacing: 14) {
                    SimpleTextField(
                        placeholder: "New Password",
                        text: $newPassword,
                        isSecure: true,
                        brandColor: brandColor
                    )

                    SimpleTextField(
                        placeholder: "Confirm New Password",
                        text: $confirmPassword,
                        isSecure: true,
                        brandColor: brandColor
                    )
                }
                
                if !newPassword.isEmpty || !confirmPassword.isEmpty {
                    passwordValidationView
                }

                SimpleButton(
                    title: "Update Password",
                    isLoading: viewModel.isLoading,
                    backgroundColor: brandColor,
                    isDisabled: viewModel.isLoading || !isPasswordValid
                ) {
                    viewModel.updatePassword(newPassword: newPassword)
                }
            }
        }
        .simpleCardStyle()
    }
    
    private var passwordValidationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !newPassword.isEmpty && newPassword.count < 6 {
                ValidationRow(text: "Password must be at least 6 characters", isValid: false)
            }
            
            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                ValidationRow(text: "Passwords do not match", isValid: false)
            }
            
            if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 6 {
                ValidationRow(text: "Passwords match", isValid: true)
            }
        }
        .padding(.top, 8)
    }
    
    private var isPasswordValid: Bool {
        return !newPassword.isEmpty &&
               !confirmPassword.isEmpty &&
               newPassword == confirmPassword &&
               newPassword.count >= 6
    }

    private var messageView: some View {
        Group {
            if let message = viewModel.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 15))
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(message.isSuccessMessage ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .foregroundColor(message.isSuccessMessage ? .green : .red)
                    .cornerRadius(12)
                    .transition(.opacity)
            }
        }
    }
    
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(brandColor)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(subtitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    private func setupView() {
        viewModel.detectUserSignInProvider()
        viewModel.resetMessages()
        if let email = viewModel.currentUserEmail {
            loginVM.email = email
        }
    }
}

// MARK: - Simple Components

struct ValidationRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
                .font(.system(size: 14))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(isValid ? .green : .red)
            
            Spacer()
        }
    }
}

struct SimpleButton: View {
    let title: String
    let isLoading: Bool
    let backgroundColor: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct SimpleTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    let brandColor: Color
    
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .focused($isFocused)
        .font(.system(size: 16))
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? brandColor : Color.clear, lineWidth: 2)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
    }
}

struct SimpleGoogleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleLogo")
                    .resizable()
                    .frame(width: 20, height: 20)

                Text("Reauthenticate with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Extensions

extension View {
    func simpleCardStyle() -> some View {
        self
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
    }
}

private extension String {
    var isSuccessMessage: Bool {
        contains("successfully") || contains("updated") || contains("changed")
    }
}
