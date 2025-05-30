import SwiftUI

struct SettingsView: View {
    var likedVideos: [String]
    var savedVideos: [String]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsSection(title: "Your activity") {
                            SettingsRow(title: "Liked", icon: "heart", destination: LikedView(videoThumnails: likedVideos))
                            SettingsRow(title: "Saved", icon: "bookmark", destination: SavedView(videoThumnails: savedVideos))
                        }

                        DividerLine()

                        SettingsSection(title: "Content") {
                            SettingsRow(title: "Change Level", destination: ChangeLevelView())
                            SettingsRow(title: "Change Languague", destination: ChangeLanguageView()) 
                        }

                        DividerLine()

                        SettingsSection(title: "Account") {
                            SettingsRow(title: "Change password", destination: ChangePasswordView())
                            SettingsRow(title: "Change email", destination: ChangeEmailView())
                            SettingsRow(title: "Log out", destination: LogoutConfirmationView(), isDestructive: true)
                            SettingsRow(title: "Delete account", destination: DeleteAccountConfirmationView(), isDestructive: true)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 16)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

struct SettingsRow<Destination: View>: View {
    var title: String
    var icon: String? = nil
    var destination: Destination
    var isDestructive: Bool = false

    var body: some View {
        NavigationLink(destination: destination) {
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 0.25)) // Match the divider gray tone in Figma
            .frame(height: 5)
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
        VideoGridSection(videoThumbnails: videoThumnails, emptyMsg: "No videos liked yet.")
    }
}

struct SavedView: View {
    var videoThumnails: [String] = []
    var body: some View {
        VideoGridSection(videoThumbnails: videoThumnails, emptyMsg: "No videos saved yet.")
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

struct LogoutConfirmationView: View {
    var body: some View {
        Text("Are you sure you want to log out?")
            .navigationTitle("Log Out")
    }
}

struct DeleteAccountConfirmationView: View {
    var body: some View {
        Text("Are you sure you want to delete your account?")
            .navigationTitle("Delete Account")
    }
}
