//
//  TermsOfServiceView.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 8/4/25.
//


import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Terms of Service")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Effective Date: August 3, 2025")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 16)
                
                // Introduction
                Text("Welcome to LiNGUiD, a language learning platform operated by LiNGUiD LLC (\"we,\" \"us,\" or \"our\"). These Terms of Service (\"Terms\") govern your use of the LiNGUiD app, website, and related services (collectively, the \"Services\"). By accessing or using our Services, you agree to these Terms. If you do not agree, please do not use the Services.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                
                // Section 1
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Using the Services")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("• Eligibility: You must be at least 13 years old to use the Services. By using the Services, you confirm that you meet this age requirement.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Account Responsibility: You are responsible for all activities under your account. Keep your password secure and notify us immediately of any unauthorized access.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Permitted Use: Use the Services for personal, non-commercial purposes unless otherwise authorized. Do not use the Services for illegal activities, harassment, or violating others' rights.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 2
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Content Ownership and License")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("• Your Content: You retain ownership of the content you create or post (e.g., language exercises, comments, or audio recordings). By posting content, you grant LiNGUiD LLC a non-exclusive, royalty-free, worldwide, transferable license to use, reproduce, modify, distribute, and display your content to operate and promote the Services. This license ends when you delete your content or account, except for content shared publicly or with others.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Feedback: Suggestions or feedback you provide may be used by us without compensation or obligation.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Our Content: All app content, including lessons, designs, and trademarks, is owned by LiNGUiD LLC or its licensors and is protected by intellectual property laws.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 3
                VStack(alignment: .leading, spacing: 12) {
                    Text("3. Community Standards")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("You agree not to:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("• Post content that is unlawful, offensive, defamatory, or infringes on others' rights.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Use the Services to distribute spam, malware, or harmful content.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Attempt to access or collect data from other users without permission.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Violate these Terms or any applicable laws.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("We may remove content or suspend accounts that violate these standards, with or without notice.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 4
                VStack(alignment: .leading, spacing: 12) {
                    Text("4. Arbitration and Dispute Resolution")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("• Binding Arbitration: Any disputes arising from these Terms or your use of the Services will be resolved through binding arbitration, except for claims that can be filed in small claims court. Arbitration will be conducted in accordance with the rules of the American Arbitration Association in California, USA.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• No Class Actions: You agree to resolve disputes individually, not as part of a class action or representative action.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Opt-Out: You may opt out of arbitration by sending written notice to LiNGUiD LLC within 30 days of accepting these Terms.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 5
                VStack(alignment: .leading, spacing: 12) {
                    Text("5. Termination")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We may suspend or terminate your account for violating these Terms, with or without notice. You may delete your account at any time by contacting support@linguidapp.com. Upon termination, your license to use the Services ends, but certain provisions (e.g., arbitration, content licenses) survive.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 6
                VStack(alignment: .leading, spacing: 12) {
                    Text("6. Disclaimers and Limitations of Liability")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("• As-Is Basis: The Services are provided \"as is\" without warranties of any kind, express or implied.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Limitation of Liability: To the fullest extent permitted by law, LiNGUiD LLC is not liable for indirect, incidental, or consequential damages arising from your use of the Services.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Indemnity: You agree to indemnify LiNGUiD LLC against claims arising from your content, use of the Services, or violation of these Terms.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Section 7
                VStack(alignment: .leading, spacing: 12) {
                    Text("7. Miscellaneous")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("• Governing Law: These Terms are governed by the laws of California, USA, excluding conflict of law principles.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Changes to Terms: We may update these Terms and will notify you of significant changes. Continued use after the effective date constitutes acceptance.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Entire Agreement: These Terms constitute the entire agreement between you and LiNGUiD LLC regarding the Services.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Contact
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("For questions about these Terms, contact:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("LiNGUiD LLC")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("learnwithlinguid@gmail.com")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black)
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
                
                Text("Terms Of Service")
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
    }
}
