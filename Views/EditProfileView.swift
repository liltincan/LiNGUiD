import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var profileImage: Image?
    @State private var inputImage: UIImage? // This is the original image from the picker
    @State private var isShowingImagePicker = false
    @State private var username: String
    @State private var profilePictureURL: String?
    @State private var isLoading: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var shouldDeleteProfilePicture: Bool = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var isCheckingUsername = false

    var currentUsername: String
    var initialProfilePictureURL: URL?

    init(currentUsername: String, currentProfilePictureURL: URL?) {
        self.currentUsername = currentUsername
        self.initialProfilePictureURL = currentProfilePictureURL
        _username = State(initialValue: currentUsername)
        _profilePictureURL = State(initialValue: currentProfilePictureURL?.absoluteString)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack(alignment: .topTrailing) {
                if let profileImage = profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 7)
                        .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                } else if let urlString = profilePictureURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .shadow(radius: 7)
                                .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                        case .failure(_):
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.secondary)
                }

                if profilePictureURL != nil || profileImage != nil {
                    Button(action: {
                        shouldDeleteProfilePicture = true
                        profileImage = nil
                        inputImage = nil
                        profilePictureURL = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .offset(x: 10, y: -10)
                    .disabled(isLoading)
                }
            }

            Button(action: {
                isShowingImagePicker = true
            }) {
                Text("Edit Photo")
                    .font(.headline)
                    .foregroundColor(Color.appPrimaryColor)
            }
            .sheet(isPresented: $isShowingImagePicker, onDismiss: loadImage) {
                ImagePicker(image: $inputImage)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Username:")
                    .font(.headline)
                TextField("Enter username", text: $username)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: username) { _ in
                        checkUsernameAvailability(username)
                    }
                
                // Username validation feedback
                if isCheckingUsername {
                    Text("Checking availability...")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.top, 2)
                } else if let available = isUsernameAvailable {
                    if !available {
                        Text("Username is already taken!")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 2)
                    } else if username != currentUsername {
                        Text("Username is available!")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                Task {
                    await saveProfile()
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appSecondaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                } else {
                    Text(isCheckingUsername ? "Checking..." : "Save")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.appPrimaryColor : Color.appSecondaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }
            }
            .disabled(isLoading || !canSave || isCheckingUsername)
            .padding(.bottom, 30)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check username availability when view appears if username is different from current
            if username != currentUsername {
                checkUsernameAvailability(username)
            }
        }
    }
    
    // Computed property to determine if save button should be enabled
    private var canSave: Bool {
        // If username hasn't changed, allow save
        if username == currentUsername {
            return true
        }
        
        // If username has changed, require it to be available
        return !username.isEmpty && isUsernameAvailable == true
    }

    func loadImage() {
        guard let inputImage = inputImage else { return }

        profileImage = Image(uiImage: inputImage)
        profilePictureURL = nil
        shouldDeleteProfilePicture = false
    }

    // MARK: - Username Availability Check
    func checkUsernameAvailability(_ name: String) {
        // If username hasn't changed from current, don't check
        guard name != currentUsername else {
            isUsernameAvailable = nil
            return
        }
        
        guard !name.isEmpty else {
            isUsernameAvailable = nil
            return
        }

        isCheckingUsername = true
        let db = Firestore.firestore()

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            isUsernameAvailable = nil
            isCheckingUsername = false
            return
        }

        db.collection("users")
            .whereField("userName", isEqualTo: name)
            .getDocuments { snapshot, error in
                isCheckingUsername = false

                if let error = error {
                    print("Error checking username: \(error.localizedDescription)")
                    isUsernameAvailable = nil
                    return
                }

                if let documents = snapshot?.documents {
                    // Check if any other user (not the current user) has this username
                    let takenByAnotherUser = documents.contains { doc in
                        doc.documentID != currentUserID
                    }

                    isUsernameAvailable = !takenByAnotherUser
                } else {
                    isUsernameAvailable = true
                }
            }
    }

    // MARK: - Image Resizing Helper
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }


    func saveProfile() async {
        isLoading = true

        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not authenticated. Please log in to save your profile.")
            isLoading = false
            return
        }

        if shouldDeleteProfilePicture {
            let storageRef = Storage.storage().reference()
            let profileImagesRef = storageRef.child("profile_photos/\(userId)/profile.jpg")

            do {
                try await profileImagesRef.delete()
                print("Profile picture deleted from Storage.")
            } catch StorageErrorCode.objectNotFound {
                print("Profile picture not found in Storage, but proceeding to remove URL from Firestore.")
            } catch {
                print("Error deleting profile picture from Storage: \(error.localizedDescription)")
                isLoading = false
                return
            }
            profilePictureURL = nil
        }

        if let uiImage = inputImage {
            // MARK: Resize Image to 200x200 before uploading
            let targetSize = CGSize(width: 500, height: 500)
            guard let resizedImage = resizeImage(image: uiImage, targetSize: targetSize) else {
                print("Failed to resize image.")
                isLoading = false
                return
            }

            guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
                print("Failed to convert resized image to Data.")
                isLoading = false
                return
            }

            let storageRef = Storage.storage().reference()
            let profileImagesRef = storageRef.child("profile_photos/\(userId)/profile.jpg")

            do {
                let _ = try await profileImagesRef.putDataAsync(imageData)
                let downloadURL = try await profileImagesRef.downloadURL()
                profilePictureURL = downloadURL.absoluteString
                print("Resized profile image uploaded. Download URL: \(downloadURL.absoluteString)")
            } catch {
                print("Error uploading resized image or getting URL: \(error.localizedDescription)")
                isLoading = false
                return
            }
        }

        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userId).setData([
                "userName": username,
                "profilePhotoUrl": profilePictureURL ?? NSNull()
            ], merge: true)
        } catch {
            print("Error saving profile data to Firestore: \(error.localizedDescription)")
        }

        isLoading = false
        shouldDeleteProfilePicture = false

        // Dismiss the view after saving
        presentationMode.wrappedValue.dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
