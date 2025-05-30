//
// LogoutButton.swift
// LiNGUiD
//
// Created by Soumil Voona on 5/28/25.
//

import SwiftUI

struct LogoutButton: View {
    @StateObject private var vm = LoginViewModel() // Assuming LoginViewModel handles the logout logic
    @EnvironmentObject var state: AppState // This is the AppState from your main app

    var body: some View {
        Button {
            Task {
                // Call the logout method from your ViewModel
                let success = vm.logout() // Assuming vm.logout() returns a Bool indicating success

                // If logout was successful, update the AppState
                if success {
                    // This line is the key! It tells the AppState that the user is no longer signed in.
                    // The main app struct (LiNGUiDApp.swift) will observe this change
                    // and switch to displaying the LoginView.
                    state.isSignedIn = false
                    print("Logout successful. AppState.isSignedIn set to false.")
                } else {
                    // Handle logout failure (e.g., show an alert)
                    print("Logout failed.")
                    // You might want vm.errorMessage to be set by vm.logout() if it fails
                    // and then display it in a SwiftUI alert if needed.
                }
            }
        } label: {
            Text("Log Out")
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                .cornerRadius(10)
        }
    }
}
