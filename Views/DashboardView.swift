import SwiftUI

struct DashboardView: View {

    @ObservedObject var userSession: UserSessionViewModel

    @StateObject var userModel: DashboardViewModel

    @Environment(\.colorScheme) var colorScheme
    
    @State private var didAppear = false


    init(userSession: UserSessionViewModel) {
        _userModel = StateObject(
            wrappedValue: DashboardViewModel(userSession: userSession)
        )
        self.userSession = userSession
    }

    var body: some View {
        VStack{
            if userModel.isLoading {
                ProgressView("Refreshing...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .font(.headline)
            } else {
                VStack(spacing: 20) {
                    AppTitleText(title: "DASHBOARD")

                    Spacer().frame(height: 10)

                    GeometryReader { geometry in
                        let boxSize = (geometry.size.width - 20) / 2  // 2 boxes, 20 spacing, 20 padding

                        HStack(spacing: 20) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    colorScheme == .dark
                                        ? Color.white : Color.gray.opacity(0.1)
                                )
                                .frame(width: boxSize, height: boxSize)
                                .overlay(content: {
                                    ZStack {
                                        VStack {
                                            Text("Level")
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )
                                                .font(
                                                    .system(size: 16, weight: .bold)
                                                )
                                                .foregroundStyle(Color.black)
                                            Spacer()
                                        }.padding(20)
                                        VStack {
                                            Text("\(userModel.userLevel)")
                                                .font(.system(size: 42))
                                                .foregroundStyle(Color.black)
                                        }
                                    }
                                })

                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    colorScheme == .dark
                                        ? Color.white : Color.gray.opacity(0.1)
                                )
                                .frame(width: boxSize, height: boxSize)
                                .overlay(content: {
                                    ZStack {
                                        VStack {
                                            Text("Hours")
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )
                                                .font(
                                                    .system(size: 16, weight: .bold)
                                                )
                                                .foregroundStyle(Color.black)
                                            Spacer()
                                        }.padding(20)
                                        VStack {
                                            Text("\(userModel.totalWatchTime, specifier: "%.f")")
                                                .font(.system(size: 42))
                                                .foregroundStyle(Color.black)
                                        }
                                    }
                                })
                        }
                    }
                    .frame(height: 200)

                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(20)
            }
        }.onAppear {
            Task {
                await userModel.fetchUserData()
            }
        }
        

    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(userSession: UserSessionViewModel())
    }
}
