import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject private var viewModel: DashboardViewModel

    @State private var showPopup = false
    @State private var selectedWordIndex: Int? = nil
    @State private var popupPosition: CGPoint = .zero
    @State private var selectedWord: WordPair? = nil

    init() {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                userSession: UserSessionViewModel()
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .foregroundColor(.white)
                        } else {
                            headerStatsSection
                            leaderboardSection
                                .padding(.top, -10)
                            calendarSection
                                .padding(.top, 50)
                            savedWordsSection
                        }
                    }
                    .padding()
                }
                .coordinateSpace(name: "SavedWordsScroll")

                if selectedWordIndex != nil && selectedWord != nil {
                    if let word = selectedWord {
                        popupMenu(for: word)
                            .position(
                                x: popupPosition.x + 130,
                                y: popupPosition.y - 90
                            )
                            .zIndex(10)
                    }

                }
            }
            .navigationTitle("DASHBOARD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DASHBOARD")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            viewModel.userSession = userSession
            Task {
                await viewModel.loadDashboardData()
            }
        }
    }

    private var headerStatsSection: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Level")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Text("\(viewModel.userLevel)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color.white)
            .cornerRadius(16)

            VStack(spacing: 8) {
                Text("Hours")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Text("\(viewModel.totalHours)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
                Text("+\(viewModel.monthlyHoursIncrease) this month")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color.white)
            .cornerRadius(16)
        }
    }

    private var leaderboardSection: some View {
        VStack(spacing: 10) {
            ZStack {
                if let centerUser = viewModel.leaderboardUsers.first(where: {
                    $0.rank == 1
                }) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)

                            AsyncImage(url: URL(string: centerUser.avatarURL)) {
                                image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 60))
                            }
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())

                            Circle()
                                .fill(Color.appPrimaryColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("1")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 25, y: -25)
                        }

                        Text(centerUser.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text("1 hr")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                ForEach(
                    viewModel.leaderboardUsers.filter { $0.rank != 1 },
                    id: \.id
                ) { user in
                    LeaderboardUserView(user: user)
                        .offset(offsetForRank(user.rank))
                }
            }
            .frame(height: 250)
        }
    }

    private var calendarSection: some View {
        VStack(spacing: 16) {
            Text(viewModel.currentMonth)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            CalendarGridView(studyDates: viewModel.studyDates)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private var savedWordsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Saved words")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                NavigationLink {
                    PracticeView(userSession: userSession)
                } label: {
                    Text("practice")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 10)
                        .background(Color.appPrimaryColor)
                        .cornerRadius(10)
                }
            }

            VStack(spacing: 10) {
                ForEach(viewModel.savedWords.indices, id: \.self) { index in
                    let word = viewModel.savedWords[index]

                    VStack(alignment: .leading) {
                        GeometryReader { geo in
                            HStack(spacing: 20) {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(
                                                .system(
                                                    size: 16,
                                                    weight: .medium
                                                )
                                            )
                                            .foregroundStyle(Color.black)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(word.target)
                                        .font(
                                            .system(size: 16, weight: .medium)
                                        )
                                        .foregroundColor(.black)
                                    Text(word.native)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedWordIndex = index
                                    selectedWord = word
                                    popupPosition =
                                        geo.frame(
                                            in: .named("SavedWordsScroll")
                                        ).origin
                                }
                            }
                        }
                        .frame(height: 50)

                        if index < viewModel.savedWords.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    private func popupMenu(for word: WordPair) -> some View {
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(word.native)
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.top)

                Spacer().frame(height: 10)

                Divider()
                    .frame(height: 2)
                    .background(Color.white)

                Button(action: {
                    // practice logic here
                    selectedWord = nil
                }) {
                    HStack {
                        Image(systemName: "rectangle.3.offgrid.fill")
                        Text("Practice")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .background(Color.white)

                Button(action: {
                    // see in context logic
                    selectedWord = nil
                }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text("See in context")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.appPrimaryColor)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(radius: 8)
            .frame(width: 200)
            
            Triangle()
                .fill(Color.appPrimaryColor)
                .frame(width: 30, height: 15)
                .rotationEffect(.degrees(180))
                .offset(x: -60 ,y: -1)
        }
        
    }

    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    private func offsetForRank(_ rank: Int) -> CGSize {
        switch rank {
        case 2: return CGSize(width: -110, height: 15)
        case 3: return CGSize(width: 110, height: 15)
        case 15: return CGSize(width: 0, height: 120)
        default: return CGSize.zero
        }
    }
}

struct LeaderboardUserView: View {
    let user: LeaderboardUser

    var body: some View {
        VStack {
            ZStack {
                Circle().fill(Color.white).frame(width: 60, height: 60)
                AsyncImage(url: URL(string: user.avatarURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 45))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                Circle()
                    .fill(Color.appPrimaryColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(user.rank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 20, y: -20)
            }
            Text(user.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Text("\(user.minutes) mins")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
}

struct CalendarGridView: View {
    let studyDates: Set<Int>
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let daysInMonth = Array(1...30)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 8
            ) {
                ForEach(daysInMonth, id: \.self) { day in
                    let isStudyDay = studyDates.contains(day)
                    Text("\(day)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isStudyDay ? .white : .black)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                isStudyDay ? Color.appPrimaryColor : Color.clear
                            )
                        )
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(UserSessionViewModel())
        .preferredColorScheme(.dark)
}
