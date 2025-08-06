import SwiftUI
import MessageUI

struct RequestFeatureView: View {
    @State private var featureText = ""
    @State private var subjectText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    private let characterLimit = 100
    private let subjectLimit = 50
    private let recipientEmail = "learnwithlinguid@gmail.com"
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Request a Feature")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Tell us what feature you'd like to see")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Subject Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Subject")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(subjectText.count)/\(subjectLimit)")
                                .font(.caption)
                                .foregroundColor(subjectText.count > subjectLimit ? .red : .gray)
                        }
                        
                        // Subject Text Field
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .frame(height: 50)
                            
                            if subjectText.isEmpty {
                                Text("Enter email subject...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                            }
                            
                            TextField("", text: $subjectText)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .onChange(of: subjectText) { _, newValue in
                                    if newValue.count > subjectLimit {
                                        subjectText = String(newValue.prefix(subjectLimit))
                                    }
                                }
                        }
                    }
                    
                    // Feature Description Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Feature Description")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(featureText.count)/\(characterLimit)")
                                .font(.caption)
                                .foregroundColor(featureText.count > characterLimit ? .red : .gray)
                        }
                        
                        // Text Editor
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            
                            if featureText.isEmpty {
                                Text("Describe the feature you'd like to see...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $featureText)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.clear)
                                .scrollContentBackground(.hidden)
                                .onChange(of: featureText) { _, newValue in
                                    if newValue.count > characterLimit {
                                        featureText = String(newValue.prefix(characterLimit))
                                    }
                                }
                        }
                        .frame(height: 100)
                    }
                    
                    Spacer()
                    
                    // Open Email Button
                    Button(action: openEmailApp) {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.headline)
                            
                            Text("Open in Email App")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    canOpenEmail ?
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(!canOpenEmail)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canOpenEmail: Bool {
        !subjectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !featureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        subjectText.count <= subjectLimit &&
        featureText.count <= characterLimit
    }
    
    private func openEmailApp() {
        guard canOpenEmail else { return }
        
        let encodedSubject = subjectText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = featureText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Create mailto URL
        let mailtoString = "mailto:\(recipientEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let mailtoURL = URL(string: mailtoString) else {
            errorMessage = "Failed to create email URL"
            showError = true
            return
        }
        
        // Check if device can open email
        if UIApplication.shared.canOpenURL(mailtoURL) {
            UIApplication.shared.open(mailtoURL) { success in
                if success {
                    // Email app opened successfully, dismiss this view
                    dismiss()
                } else {
                    errorMessage = "Failed to open email app"
                    showError = true
                }
            }
        } else {
            errorMessage = "No email app is configured on this device"
            showError = true
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
