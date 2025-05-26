//
//  AppSocialLoginButton.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/24/25.
//
import SwiftUI

struct AppSocialLoginButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(text)
                    .foregroundColor(.black)
                    .fontWeight(.medium)
                    .font(.system(size: 20))

                       
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.white))
            .cornerRadius(10)
        }
    }
}
