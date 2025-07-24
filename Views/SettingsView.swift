import SwiftUI
import Photos
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    var likedVideos: [String]
    var likedVideoURLs: [String]
    var savedVideos: [String]
    var savedVideoURLs: [String]
    var likedVideoArray: [Video]
    var savedVideoArray: [Video]
    var languages: Set<String>
    var uid: String?
    var selectedNativeLanguages: Set<String>
    @State private var showLogoutAlert = false
    @StateObject private var loginVM = LoginViewModel()
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTab: Int
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        GoProSection()
                        
                        DividerLine()
                        
                        SettingsSection(title: "Your activity") {
                            SettingsRowLink(title: "Liked", icon: "heart", destination: LikedView(videoThumbnails: likedVideos, videoURLs: likedVideoURLs, likedVideoArray: likedVideoArray, selectedTab: $selectedTab))
                            SettingsRowLink(title: "Saved", icon: "bookmark", destination: SavedView(videoThumbnails: savedVideos, videoURLs: savedVideoURLs, savedVideoArray: savedVideoArray, selectedTab: $selectedTab))
                        }

                        DividerLine()

                        SettingsSection(title: "Content") {
                            SettingsRowLink(title: "Change Level", destination: ChangeLanguageLevelFlow(selectedLanguagesArray: Array(languages), uid: uid!))
                            SettingsRowLink(title: "Change Language", destination: ChangeLanguageFlowView(uid: uid!, preselectedLanguageCodes: languages, selectedNativeLanguages: selectedNativeLanguages))
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
        let result = loginVM.logout()
        
        if result {
            onLogout()
            dismiss()
        }
    }
}

struct GoProSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Go Pro")
                .font(UIConstants.sectionFont)
                .foregroundColor(UIConstants.sectionColor)
                .padding(.bottom, 12)
            
            NavigationLink(destination: GetProView()) {
                HStack {
                    Image("linguid_pro_banner")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
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
            .fill(Color(white: 0.25))
            .frame(height: 1)
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
    static let appPrimaryColor = Color(red: 90/255, green: 200/255, blue: 250/255)
}

// MARK: - Liked and Saved Views

struct LikedView: View {
    var videoThumbnails: [String]
    var videoURLs: [String]
    var likedVideoArray: [Video]
    @Binding var selectedTab: Int
    var body: some View {
        ScrollView {
            VideoGridSection(videoThumbnails: videoThumbnails, videoURLs: videoURLs, uploadingVideos: [], noVideosMessage: "You haven't liked any videos yet.", videoArray: likedVideoArray, selectedTab: $selectedTab)
        }
        .navigationTitle("Liked Videos")
    }
}

struct SavedView: View {
    var videoThumbnails: [String]
    var videoURLs: [String]
    var savedVideoArray: [Video]
    @Binding var selectedTab: Int
    var body: some View {
        ScrollView {
            VideoGridSection(videoThumbnails: videoThumbnails, videoURLs: videoURLs, uploadingVideos: [], noVideosMessage: "You haven't saved any videos yet.", videoArray: savedVideoArray, selectedTab: $selectedTab)
        }
        .navigationTitle("Saved Videos")
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
        Text("About Linguid")
            .navigationTitle("About")
    }
}

struct PrivacyView: View {
    var body: some View {
        Text("Linguid Privacy Policy")
            .navigationTitle("Privacy")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Linguid Help Center")
            .navigationTitle("Help")
    }
}

struct RequestFeatureView: View {
    var body: some View {
        Text("Request a New Feature")
            .navigationTitle("Request a Feature")
    }
}

struct GoProView: View {
    var body: some View {
        Text("Go Pro Features")
            .navigationTitle("Go Pro")
    }
}
