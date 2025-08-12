//
//  PrivacyPolicyView.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 8/4/25.
//


import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy Policy")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Effective Date: August 3, 2025")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 16)
                
                // Introduction
                Text("At LiNGUiD LLC, we value your privacy and are committed to transparency about how we collect, use, and protect your information. This Privacy Policy explains how LiNGUiD LLC (\"we,\" \"us,\" or \"our\") handles your personal data when you use the LiNGUiD app, website, or related services (collectively, the \"Services\"). By using our Services, you agree to the practices described in this policy.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                
                // Information We Collect
                VStack(alignment: .leading, spacing: 12) {
                    Text("Information We Collect")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We collect information to enhance your language learning experience, provide personalized content, and improve our Services. The types of information we collect include:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Information You Provide: When you create a LiNGUiD account, you provide details such as your name, email address, username, password, and optionally, your phone number or profile picture. You may also share content like language exercises, comments, or messages with other users.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Content You Create: We collect the content you post, such as language practice submissions, audio recordings, flashcards, or comments, along with associated metadata (e.g., timestamps or location, if enabled).")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Interactions and Usage: We track how you interact with the Services, including lessons completed, quizzes taken, users you follow, and content you like or share. We also collect device information (e.g., IP address, device type, operating system) and usage data (e.g., time spent on lessons).")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Third-Party Connections: If you link your LiNGUiD account to other platforms (e.g., social media for sharing progress), we may receive information from those platforms, subject to their privacy policies.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Cookies and Tracking: We use cookies and similar technologies to improve functionality, analyze usage, and deliver personalized content, such as tailored language exercises.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // How We Use Your Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("How We Use Your Information")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We use your information to provide, personalize, and improve the LiNGUiD experience. Specifically, we may:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Deliver customized language lessons, quizzes, and recommendations based on your learning progress and preferences.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Facilitate social interactions, such as connecting with other learners, sharing achievements, or messaging.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Analyze usage trends to enhance app features, like improving lesson algorithms or developing new learning tools.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Send you notifications, updates, or promotional content (you can opt out of marketing communications).")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Comply with legal obligations, prevent fraud, or protect the safety of our users and Services.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Sharing Your Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sharing Your Information")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We share your information under specific circumstances, including:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Public Content: Content you post publicly, like shared flashcards or public profile details, can be viewed, used, or shared by others.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Service Providers: We work with trusted partners (e.g., cloud hosting, analytics providers) who process data on our behalf, bound by strict confidentiality agreements.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Legal Requirements: We may disclose data to comply with legal requests, such as court orders or subpoenas, or to protect our rights, property, or safety.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Business Transfers: In the event of a merger, acquisition, or sale, your data may be transferred as part of the business assets, subject to this policy.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Your Privacy Choices
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Privacy Choices")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("You have control over your data through the following options:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Account Settings: Adjust privacy settings to control who sees your profile, posts, or learning progress.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Data Access and Deletion: Request a copy of your data or ask us to delete your account by contacting support@linguidapp.com.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Cookies: Manage cookie preferences through your browser settings.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Text("• Opt-Out: Unsubscribe from marketing emails or disable push notifications in the app.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Data Security
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Security")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We use reasonable safeguards, such as encryption and access controls, to protect your data. However, no system is completely secure, and you are responsible for maintaining the confidentiality of your account credentials.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // International Data Transfers
                VStack(alignment: .leading, spacing: 12) {
                    Text("International Data Transfers")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("LiNGUiD LLC operates globally, and your data may be stored or processed in the United States or other countries where our partners operate. These locations may have different data protection laws. By using our Services, you consent to such transfers.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Children's Privacy
                VStack(alignment: .leading, spacing: 12) {
                    Text("Children's Privacy")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Our Services are not intended for users under 13 years of age. We do not knowingly collect data from children under 13 without parental consent. If we learn of such data collection, we will delete it promptly.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Changes to This Policy
                VStack(alignment: .leading, spacing: 12) {
                    Text("Changes to This Policy")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("We may update this Privacy Policy to reflect changes in our practices or legal requirements. We will notify you of significant changes via email or in-app notifications. Continued use of the Services after the effective date constitutes acceptance of the updated policy.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Contact
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("For questions about this Privacy Policy, contact us at:")
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
                
                Text("Privacy Policy")
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
