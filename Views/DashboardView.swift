import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var savedWordsViewModel: SavedWordViewModel

    @Binding var selectedTab: Int

    @State private var showPopup = false
    @State private var selectedWordIndex: Int? = nil
    @State private var popupPosition: CGPoint = .zero
    @State private var selectedWord: WordPair? = nil
    @State private var translatedText: String? = nil
    @State private var isTranslating = false
    @State private var openPractice = false
    
    // Computed property to control which users are displayed in leaderboard
    private var displayedLeaderboardUsers: [LeaderboardUser] {
        let nonFirstPlaceUsers = viewModel.leaderboardUsers.filter { $0.rank != 1 }
        let currentUserAuthUID = FirebaseAuth.Auth.auth().currentUser?.uid
        
        // Always show rank 2 and 3 users (don't exclude current user)
        let topUsers = nonFirstPlaceUsers.filter { user in
            user.rank == 2 || user.rank == 3
        }
        
        // Always add current user at the bottom (even if they're already in top 3)
        let currentUser = viewModel.leaderboardUsers.first { user in
            user.id == currentUserAuthUID
        }
        
        if let currentUser = currentUser {
            return topUsers + [currentUser]
        }
        return topUsers
    }

    init(userSession: UserSessionViewModel, selectedTab: Binding<Int>) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                userSession: userSession
            )
        )
        _savedWordsViewModel = StateObject(
            wrappedValue: SavedWordViewModel(userSession: userSession)
        )

        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Loading Dashboard...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else if !viewModel.errorMessage.isEmpty {
                    // Error state display
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Loading Failed")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(viewModel.errorMessage)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadDashboardData()
                            }
                        }
                        .padding()
                        .background(Color.appPrimaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerStatsSection
                            leaderboardSection
                                .padding(.top, -10)
                            calendarSection
                                .padding(.top, 50)
                            savedWordsSection
                        }
                        .padding()
                    }
                    .coordinateSpace(name: "SavedWordsScroll")
                    .allowsHitTesting(selectedWord == nil)  // disable scrolling when popup is shown

                    if selectedWord != nil, selectedWordIndex != nil {
                        // Background tap dismiss layer
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    selectedWord = nil
                                    translatedText = nil
                                    selectedWordIndex = nil
                                }
                            }

                        popupMenu(
                            for: translatedText,
                            from: viewModel.user?.targetLanguage ?? "",
                            to: viewModel.user?.nativeLanguage ?? "",
                            wordPair: selectedWord
                                ?? WordPair.init(target: "", native: "")
                        )
                        .position(
                            x: popupPosition.x + 130,
                            y: popupPosition.y - 90
                        )
                        .zIndex(10)
                    }
                    NavigationLink("", isActive: $openPractice) {
                        PracticeWordView(
                            userSession: userSession,
                            savedWordsViewModel: savedWordsViewModel
                        )
                    }
                    .hidden()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenPracticeFromPopup"))) { _ in
                openPractice = true
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
            .onChange(of: selectedTab) { oldTab, newTab in
                if newTab != 2 {
                    withAnimation {
                        selectedWord = nil
                        selectedWordIndex = nil
                        translatedText = nil
                    }
                }
            }
        }
        .onAppear {
            selectedWord = nil
            selectedWordIndex = nil
            translatedText = nil

            Task {
                await viewModel.loadDashboardData()
                print("fetching words")
                await savedWordsViewModel.fetchLanguageData()
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
                Text(String(format: "%.1f", viewModel.totalHours))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
                Text(String(format: "+%.1f this month", viewModel.monthlyHoursIncrease))
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
        VStack(spacing: 15) {
            if viewModel.leaderboardUsers.isEmpty {
                // Leaderboard empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Loading Leaderboard...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(height: 200)
            } else {
                ZStack {
                    if let centerUser = viewModel.leaderboardUsers.first(where: {
                        $0.rank == 1
                    }) {
                        VStack(spacing: 8) {
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
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text("1")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .minimumScaleFactor(0.7)
                                            .lineLimit(1)
                                    )
                                    .offset(x: 26, y: -26)
                            }

                            VStack(spacing: 3) {
                                Text(centerUser.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("\(centerUser.minutes) mins")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100)
                        }
                    }

                    ForEach(
                        Array(displayedLeaderboardUsers.enumerated()),
                        id: \.offset
                    ) { index, user in
                        LeaderboardUserView(user: user)
                            .offset(offsetForUser(user, at: index))
                    }
                }
                .frame(height: 320)
            }
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

            if viewModel.savedWords.isEmpty {
                // Empty state display
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Saved Words")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Save words while watching videos, they will appear here")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 30)
            } else {
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
                                    actionFunction(
                                        index: index,
                                        geo: geo,
                                        word: word
                                    )
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
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    func actionFunction(index: Int, geo: GeometryProxy, word: WordPair) {
        isTranslating = true
        withAnimation {
//            translateWithMyMemory(
//                text: word.target,
//                from: viewModel.targetLanguage ?? "",
//                to: viewModel.nativeLanguage ?? ""
//            ) { result, source in
//                DispatchQueue.main.async {
//                    isTranslating = false
//                    translatedText = result
//                    print(
//                        "Translated: \(result ?? "Failed")\nSource: \(source ?? "Failed")"
//                    )
//
//                }
//            }
            translateTextV2(
                text: word.target,
                sourceLang: viewModel.targetLanguage ?? "",
                targetLang: viewModel.nativeLanguage ?? ""
            ) { result in
                if let translated = result {
                    isTranslating = false
                    translatedText = translated
                    print("🇩🇪 Translated Text: \(translated)")
                } else {
                    print("❌ Translation failed.")
                }
            }
            selectedWordIndex = index
            selectedWord = word
            popupPosition =
                geo.frame(
                    in: .named("SavedWordsScroll")
                ).origin
        }
    }

    private func popupMenu(
        for word: String?,
        from targetLanguage: String,
        to nativeLanguage: String,
        wordPair: WordPair
    ) -> some View {
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                if isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, 15)

                        Text("Translating...")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.top, 15)
                    }
                } else if let translated = translatedText {
                    Text(translated)
                        .font(.system(size: 24, weight: .semibold))
                        .padding(.top)
                }

                Spacer().frame(height: 10)

                Divider()
                    .frame(height: 2)
                    .background(Color.white)

                NavigationLink {
                    PracticeWordView(
                        userSession: userSession,
                        savedWordsViewModel: savedWordsViewModel
                    )
                } label: {
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
                .offset(x: -60, y: -1)
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

    private func offsetForUser(_ user: LeaderboardUser, at index: Int) -> CGSize {
        let currentUserAuthUID = FirebaseAuth.Auth.auth().currentUser?.uid
        
        // If this is the last item in the array and it's the current user, put at bottom
        if index == displayedLeaderboardUsers.count - 1 && user.id == currentUserAuthUID {
            return CGSize(width: 0, height: 160)  // Bottom position for current user
        }
        
        // Regular positions based on rank
        switch user.rank {
        case 2: return CGSize(width: -140, height: 30)  // Left
        case 3: return CGSize(width: 140, height: 30)   // Right
        case 4...Int.max: return CGSize(width: 0, height: 160)  // Bottom for low ranks
        default: return CGSize.zero
        }
    }
}

struct LeaderboardUserView: View {
    let user: LeaderboardUser

    var body: some View {
        VStack(spacing: 6) {
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
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("\(user.rank)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    )
                    .offset(x: 22, y: -22)
            }

            VStack(spacing: 2) {
                Text(user.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)

                Text("\(user.minutes) mins")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .frame(width: 100)
        }
        .frame(width: 100, height: 120)
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

//#Preview {
//    DashboardView()
//        .environmentObject(UserSessionViewModel())
//        .preferredColorScheme(.dark)
//}
