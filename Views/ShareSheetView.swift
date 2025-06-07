//
//  ShareSheetView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 6/6/25.
//

import SwiftUI

struct ShareSheetView: View {
    let videoId: String
    var body: some View {
        HStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Share this video")
                .font(.headline)

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

            Button {
                UIPasteboard.general.string = "https://learnwithlinguid.com/videos/\(videoId)"
            } label: {
                VStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Link")
                }
            }


            Button(role: .destructive) {
                // Report video logic
            } label: {
                VStack {
                    Image(systemName: "flag")
                    Text("Report")
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    ShareSheetView(videoId: "")
}
