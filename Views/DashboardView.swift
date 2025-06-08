import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject private var viewModel: DashboardViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(userSession: UserSessionViewModel()))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .foregroundColor(.white)
                        } else {
                            // Header Stats Cards
                            headerStatsSection
                            
                            // Leaderboard Circle Section
                            leaderboardSection
                                .padding(.top, -10)
                            
                            // Calendar Section
                            calendarSection
                                .padding(.top, 50)
                            
                            // Saved Words Section
                            savedWordsSection
                        }
                    }
                    .padding()
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
    
    // MARK: - Header Stats Section
    
    private var headerStatsSection: some View {
        HStack(spacing: 16) {
            // Level Card
            VStack(spacing: 8) {
                Text("Level")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                Text("\(viewModel.userLevel)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color.white)
            .cornerRadius(16)
            
            // Hours Card
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
            .frame(height: 120)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Leaderboard Section
    
    private var leaderboardSection: some View {
        VStack(spacing: 10) {
            // Top users in circle formation
            ZStack {
                // Center user (rank 1)
                if let centerUser = viewModel.leaderboardUsers.first(where: { $0.rank == 1 }) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            AsyncImage(url: URL(string: centerUser.avatarURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 60))
                            }
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                            
                            // Rank badge
                            Circle()
                                .fill(Color.purple)
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
                
                // Other users positioned around
                ForEach(viewModel.leaderboardUsers.filter { $0.rank != 1 }, id: \.id) { user in
                    LeaderboardUserView(user: user)
                        .offset(offsetForRank(user.rank))
                }
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Calendar Section
    
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
    
    // MARK: - Saved Words Section
    
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(20)
                }
            }
            
            VStack(spacing: 0) {
                ForEach(viewModel.savedWords.indices, id: \.self) { index in
                    let word = viewModel.savedWords[index]
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.target)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text(word.native)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    if index < viewModel.savedWords.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions
    
    private func offsetForRank(_ rank: Int) -> CGSize {
        switch rank {
        case 2:
            return CGSize(width: -110, height: 15)
        case 3:
            return CGSize(width: 110, height: 15)
        case 15:
            return CGSize(width: 0, height: 120)
        default:
            return CGSize.zero
        }
    }
}

// MARK: - Supporting Views

struct LeaderboardUserView: View {
    let user: LeaderboardUser
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                
                AsyncImage(url: URL(string: user.avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 45))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                
                // Rank badge
                Circle()
                    .fill(Color.purple)
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
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { day in
                    let isStudyDay = studyDates.contains(day)
                    Text("\(day)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isStudyDay ? .white : .black)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isStudyDay ? Color.purple : Color.clear)
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