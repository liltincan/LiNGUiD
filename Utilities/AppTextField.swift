//
//  AppTextField.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/24/25.
//

import SwiftUI

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecureTextEntry: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View{
        Group {
            if isSecureTextEntry {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
        }.padding(14)
            .font(.system(size: 18))
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            .foregroundColor(.black)
            .font(.custom("Poppins-Regular", size: 16))
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
    }
}
