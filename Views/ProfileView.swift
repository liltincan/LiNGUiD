import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = LoginViewModel()
    @EnvironmentObject var state: AppState


    var body: some View {
        VStack {
            
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
            Text("User Name")
                .font(.title)
            // TODO: user stats, logout button
            
            Button {
                Task {
                    let result = vm.logout()
                    if (result){
                        state.isSignedIn = false
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
        .padding()
    }
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}

