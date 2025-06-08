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

            Text("Share this video")
                .font(.headline)
                .padding(.bottom, 10)
            
            
            HStack(spacing: 20) {
                Button {
                    if let url = URL(string: "https://learnwithlinguid.com/videos/\(videoId)") {
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
                    }
                } label: {
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Link")
                    }
                }
                .padding(15)
                .buttonBorderShape(.circle)
                
                Button {
                    UIPasteboard.general.string = "https://learnwithlinguid.com/videos/\(videoId)"
                } label: {
                    VStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Link")
                    }
                }
                .buttonBorderShape(.circle)
                
                
                
                Button(role: .destructive) {
                    // Report video logic
                } label: {
                    VStack {
                        Image(systemName: "flag")
                        Text("Report")
                    }
                }
                .buttonBorderShape(.circle)
                
                Spacer()
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
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(.horizontal)
        .transition(.move(edge: .bottom))
    }
}

#Preview {
    ShareSheetView(videoId: "gMr8VMsRsz8")
}
