//
//  ShareSheetView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 6/6/25.
//

import SwiftUI

struct ShareSheetView: View {
    let videoId: String
    //let onDismiss: () -> Void
    var body: some View {
        VStack {
            
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Share")
                .font(.headline)
                .padding(.bottom, 10)
                .foregroundStyle(.white)
            
            
            HStack(spacing: 20) {
//                VStack {
//                    Button {
//                        if let url = URL(string: "https://learnwithlinguid.com/videos/\(videoId)") {
//                            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//                            UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
//                        }
//                    } label: {
//                        Image(systemName: "square.and.arrow.up")
//                        
//                    }
//                    .padding(15)
//                    .clipShape(Circle())
//                    .overlay(
//                        Circle()
//                            .stroke(Color.gray, lineWidth: 2)
//                    )
//                    
//                    Text("Share Link")
//                        .foregroundStyle(.white)
//                }
                
                VStack {
                    Button {
                        UIPasteboard.general.string = "https://learnwithlinguid.com/videos/\(videoId)"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .padding(16)
                    }
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4)
                    
                    Text("Copy Link")
                        .foregroundStyle(.white)
                }
                
                VStack {
                    Button(role: .destructive) {
                        // Report video logic
                    } label: {
                        Image(systemName: "flag")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .padding(16)
                    }
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4)
                    
                    Text("Report")
                        .foregroundStyle(.white)
                    
                }
                
                VStack {
                    Button {
                        if let url = URL(string: "https://learnwithlinguid.com/videos/\(videoId)"),
                           let messageURL = URL(string: "sms:&body=\(url.absoluteString)") {
                            UIApplication.shared.open(messageURL)
                        }
                    } label: {
                        Image(systemName: "message.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .padding(16)
                    }
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4)

                    Text("iMessage")
                        .foregroundStyle(.white)
                }
                
                VStack {
                    Button {
                        if let url = URL(string: "mailto:?subject=Check this out&body=https://learnwithlinguid.com/videos/\(videoId)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .padding(16)
                    }
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 4)

                    Text("Email")
                        .foregroundStyle(.white)
                }

                
            }
            Button("Dismiss") {
                withAnimation {
                    //onDismiss()
                }
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            Color.black
        )
        .cornerRadius(20)
        .overlay( // Optional: Add a soft white border
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.8), radius: 10)
        .padding(.horizontal)
        .transition(.move(edge: .bottom))

    }
}

#Preview {
    ShareSheetView(videoId: "gMr8VMsRsz8")
}
