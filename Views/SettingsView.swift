import SwiftUI
import Photos
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging

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
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var deletionError: String?
    @StateObject private var loginVM = LoginViewModel()
    @StateObject private var accountService = AccountDeletionService()
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTab: Int
    let onLogout: () -> Void
    @StateObject private var proVM = ProStatusViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if proVM.isPro {
                            proUserSection()
                        } else {
                            GoProSection()
                        }
                        
                        DividerLine()
                        
                        SettingsSection(title: "Your activity") {
                            SettingsRowLink(title: "Liked", icon: "heart", destination: LikedView(videoThumbnails: likedVideos, videoURLs: likedVideoURLs, likedVideoArray: likedVideoArray, selectedTab: $selectedTab, onLogout: onLogout))
                            SettingsRowLink(title: "Saved", icon: "bookmark", destination: SavedView(videoThumbnails: savedVideos, videoURLs: savedVideoURLs, savedVideoArray: savedVideoArray, selectedTab: $selectedTab, onLogout: onLogout))
                        }

                        DividerLine()

                        SettingsSection(title: "Content") {
                            SettingsRowLink(title: "Change Level", destination: ChangeLanguageLevelFlow(uid: uid!))
                            SettingsRowLink(title: "Change Language", destination: ChangeLanguageFlowView(uid: uid!, preselectedLanguageCodes: languages, selectedNativeLanguages: selectedNativeLanguages))
                        }

                        DividerLine()

                        SettingsSection(title: "Information") {
                            SettingsRowLink(title: "About", destination: AboutView())
                            SettingsRowLink(title: "Privacy", destination: PrivacyPolicyView())
                            SettingsRowLink(title: "Terms Of Service", destination: TermsOfServiceView())
                            SettingsRowLink(title: "Request a Feature", destination: RequestFeatureView())
                        }

                        DividerLine()

                        SettingsSection(title: "Account") {
                            SettingsRowLink(title: "Change password", destination: ChangePasswordView())
                            SettingsRowButton(title: "Log out", isDestructive: true) {
                                showLogoutAlert = true
                            }
                            SettingsRowButton(title: "Delete account", isDestructive: true) {
                                showDeleteAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                // Custom navigation bar
                HStack {
                    // Back button with chevron.left
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Settings")
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.black)
            }
            .toolbar(.hidden, for: .tabBar)
            .alert("Are you sure you want to log out?", isPresented: $showLogoutAlert) {
                Button("Log out", role: .destructive) {
                    logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .overlay {
                if isDeleting {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Deleting account...")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top, 16)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .alert("Error", isPresented: .constant(deletionError != nil)) {
                Button("OK") {
                    deletionError = nil
                }
            } message: {
                if let error = deletionError {
                    Text(error)
                }
            }
        }
        .onAppear {
            guard let uid = uid, !uid.isEmpty else {
                print("SettingsView: missing uid; not starting Pro listener")
                return
            }
            proVM.startListening(uid: uid)
        }
        .onDisappear {
            proVM.stopListening()
        }
    }

    func logout() {
        let result = loginVM.logout()
        
        if result {
            onLogout()
            dismiss()
        }
    }
    
    func deleteAccount() {
        isDeleting = true
        deletionError = nil
        
        Task {
            do {
                try await accountService.deleteUserAccount()
                
                await MainActor.run {
                    isDeleting = false
                    // User will be automatically signed out after deletion
                    onLogout()
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deletionError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Updated Account Deletion Service
class AccountDeletionService: ObservableObject {
    
    func deleteUserAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.notAuthenticated
        }
        
        let uid = user.uid
        print("Starting account deletion for user: \(uid)")
        
        // Use the comprehensive deletion function (includes cloud function call)
        try await FirestoreService.shared.deleteAllUserData()
        
        print("Account deletion completed successfully")
    }
}

// MARK: - Custom Errors
enum AccountDeletionError: LocalizedError {
    case notAuthenticated
    case serverError(String)
    case unexpectedResponse
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Unable to access account information"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unexpectedResponse:
            return "Unexpected response from server"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - UI Components (unchanged)
struct GoProSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Go Pro")
                .font(UIConstants.sectionFont)
                .foregroundColor(UIConstants.sectionColor)
                .padding(.bottom, 12)
            
            NavigationLink(destination: GetProView(fromSettings: true)) {
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

struct proUserSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manage Subscription")
                .font(UIConstants.sectionFont)
                .foregroundColor(UIConstants.sectionColor)
                .padding(.bottom, 12)
            
            NavigationLink(destination: ManageSubscriptionView()) {
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
    let onLogout: () -> Void
    var body: some View {
        ScrollView {
            VideoGridSection(videoThumbnails: videoThumbnails, videoURLs: videoURLs, uploadingVideos: [], noVideosMessage: "You haven't liked any videos yet.", videoArray: likedVideoArray, selectedTab: $selectedTab, fromOtherUserProfile: true, onLogout: onLogout)
        }
        .padding(.top, 20)
        .navigationTitle("Liked Videos")
    }
}

struct SavedView: View {
    var videoThumbnails: [String]
    var videoURLs: [String]
    var savedVideoArray: [Video]
    @Binding var selectedTab: Int
    let onLogout: () -> Void
    var body: some View {
        ScrollView {
            VideoGridSection(videoThumbnails: videoThumbnails, videoURLs: videoURLs, uploadingVideos: [], noVideosMessage: "You haven't saved any videos yet.", videoArray: savedVideoArray, selectedTab: $selectedTab, fromOtherUserProfile: true, onLogout: onLogout)
        }
        .padding(.top, 20)
        .navigationTitle("Saved Videos")
    }
}

struct DeleteAccountConfirmationView: View {
    var body: some View {
        Text("Are you sure you want to delete your account?")
            .navigationTitle("Delete Account")
    }
}
