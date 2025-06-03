import SwiftUI

struct SettingsView: View {
    var likedVideos: [String]
    var savedVideos: [String]
    @StateObject private var vm = LoginViewModel()
    @EnvironmentObject var state: AppState
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsSection(title: "Your activity") {
                            SettingsRowLink(title: "Liked", icon: "heart", destination: LikedView(videoThumnails: likedVideos))
                            SettingsRowLink(title: "Saved", icon: "bookmark", destination: SavedView(videoThumnails: savedVideos))
                        }

                        DividerLine()

                        SettingsSection(title: "Content") {
                            SettingsRowLink(title: "Change Level", destination: ChangeLevelView())
                            SettingsRowLink(title: "Change Language", destination: ChangeLanguageView())
                        }

                        DividerLine()
                        
                        SettingsSection(title: "Information") {
                            SettingsRowLink(title: "About", destination: AboutView())
                            SettingsRowLink(title: "Privacy", destination: PrivacyView())
                            SettingsRowLink(title: "Help", destination: HelpView())
                            SettingsRowLink(title: "Request a Feature", destination: RequestFeatureView())
                        }
                        
                        DividerLine()

                        SettingsSection(title: "Account") {
                            SettingsRowLink(title: "Change password", destination: ChangePasswordView())
                            SettingsRowLink(title: "Change email", destination: ChangeEmailView())
                            SettingsRowButton(title: "Log out", isDestructive: true) {
                                showLogoutAlert = true
                            }
                            SettingsRowLink(title: "Delete account", destination: DeleteAccountConfirmationView(), isDestructive: true)
                        }
                        
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 16)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .alert("Are you sure you want to log out?", isPresented: $showLogoutAlert) {
                Button("Log out", role: .destructive) {
                    logout()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    func logout() {
        let result = vm.logout()
        if (result){
            state.isSignedIn = false
        }
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(UIConstants.sectionFont)
                .foregroundColor(UIConstants.sectionColor)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.black)
            .cornerRadius(8)
        }
    }
}

// MARK: - Row for Navigation

struct SettingsRowLink<Destination: View>: View {
    var title: String
    var icon: String? = nil
    var destination: Destination
    var isDestructive: Bool = false

    var body: some View {
        NavigationLink(destination: destination) {
            SettingsRowContent(title: title, icon: icon, isDestructive: isDestructive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Row for Button Action

struct SettingsRowButton: View {
    var title: String
    var icon: String? = nil
    var isDestructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(title: title, icon: icon, isDestructive: isDestructive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reusable Row Content

struct SettingsRowContent: View {
    var title: String
    var icon: String? = nil
    var isDestructive: Bool = false

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: UIConstants.iconSize))
                    .foregroundColor(isDestructive ? UIConstants.redColor : .white)
                    .frame(width: 24)
            }

            Text(title)
                .font(UIConstants.rowFont)
                .foregroundColor(isDestructive ? UIConstants.redColor : .white)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14, weight: .medium))
        }
        .frame(height: UIConstants.rowHeight)
        .contentShape(Rectangle())
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 0.25)) // Match the divider gray tone in Figma
            .frame(height: 2)
            .padding(.vertical, 20)
    }
}

struct UIConstants {
    static let rowHeight: CGFloat = 40
    static let iconSize: CGFloat = 18
    static let rowFont = Font.custom("Inter-SemiBold", size: 18)
    static let sectionFont = Font.custom("Inter-Regular", size: 16)
    static let sectionColor = Color(red: 148/255, green: 148/255, blue: 148/255)
    static let redColor = Color(red: 255/255, green: 69/255, blue: 58/255)
}

// MARK: - Destination Views (Examples)

struct LikedView: View {
    var videoThumnails: [String] = []
    var body: some View {
        Text("Liked Videos")
            .navigationTitle(Text("Liked Videos"))
    }
}

struct SavedView: View {
    var videoThumnails: [String] = []
    var body: some View {
        Text("Saved Videos")
            .navigationTitle(Text("Saved Videos"))
    }
}

struct ChangeLevelView: View {
    var body: some View {
        Text("Change Level Settings")
            .navigationTitle("Change Level")
    }
}

struct ChangeLanguageView: View {
    var body: some View {
        Text("Change Language Settings")
            .navigationTitle("Change Language")
    }
}

struct ChangePasswordView: View {
    var body: some View {
        Text("Change Password Screen")
            .navigationTitle("Change Password")
    }
}

struct ChangeEmailView: View {
    var body: some View {
        Text("Change Email Screen")
            .navigationTitle("Change Email")
    }
}

struct DeleteAccountConfirmationView: View {
    var body: some View {
        Text("Are you sure you want to delete your account?")
            .navigationTitle("Delete Account")
    }
}

struct AboutView: View {
    var body: some View {
        Text("About")
            .navigationTitle("About")
    }
}

struct PrivacyView: View {
    var body: some View {
        Text("Privacy Policy")
            .navigationTitle("Privacy")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help")
            .navigationTitle("Help")
    }
}

struct RequestFeatureView: View {
    var body: some View {
        Text("Request Some Feature")
            .navigationTitle("Request a Feature")
    }
}
