import FirebaseAuth
import FirebaseFirestore
import SwiftUI

import FirebaseFirestore
import SwiftUI

struct PracticeView: View {
    @StateObject private var viewModel: SavedWordViewModel
//    @StateObject private var userSession = UserSessionViewModel()
    @ObservedObject var userSession: UserSessionViewModel



    @State private var selectedSegment: Int = 0
    @State private var isActive: Bool = false
    @State private var isLoading = false
    
    init(userSession: UserSessionViewModel) {
        self.userSession = userSession
        _viewModel = StateObject(wrappedValue: SavedWordViewModel(userSession: userSession))
    }

    @Environment(\.colorScheme) var colorScheme

    var unKnownWords: [WordPair] {
        viewModel.savedWords?.unknownWords ?? []
    }

    var knownWords: [WordPair] {
        viewModel.savedWords?.knownWords ?? []
    }
    
    

    var body: some View {
        if isLoading {
            ProgressView("Refreshing...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .font(.headline)
        } else {
            VStack {
                if knownWords.isEmpty && unKnownWords.isEmpty {
                    VStack(spacing: 8) {
                        Text("No saved words yet.")
                            .font(.title)
                            .foregroundColor(.white)

                        Text("Start saving words to practice and track your progress.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    NavigationStack {
                        VStack(spacing: 20) {
                            AppTitleText(title: "PRACTICE")

                            if let firstWord = unKnownWords.first {
                                wordCard(for: firstWord)
                                    .onTapGesture {
                                        isActive = true
                                    }
                                    .navigationDestination(isPresented: $isActive) {
                                        PracticeWordView(savedWordsViewModel: viewModel)
                                    }
                            }

                            savedWordsHeader

                            savedWordsList
                        }
                        .padding()
                    }
                }
            }
            .task {
                print("isLoading")
                await viewModel.fetchLanguageData()
            }
        }
    }


    private func wordCard(for word: WordPair) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 2)
                .fill(Color.appPrimaryColor)
                .frame(width: 300, height: 150)
                .offset(x: -20, y: -20)

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 2)
                .fill(Color.appPrimaryColor)
                .frame(width: 300, height: 150)
                .offset(x: -10, y: -10)

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 2)
                .fill(Color.appPrimaryColor)
                .frame(width: 300, height: 150)
                .overlay(
                    VStack {
                        Text(word.target)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)

                        Text("Tap to practice")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .underline()
                    }
                )
        }
        .shadow(radius: 3)
        .padding(.top, 40)
        .padding(.bottom, 10)
        .padding(.leading, 30)
    }

    private var savedWordsHeader: some View {
        HStack(spacing: 20) {
            Text("Saved Words")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Load Words") {

                let db = Firestore.firestore()
                let data: [String: Any] = [
                    "languagesData": [
                        "de": [
                            "savedWords": [
                                "knownWords": [["target": "hallo", "native": "hello"]],
                                "unknownWords": [["target": "buch", "native": "book"], ["target": "tisch", "native": "table"],["target": "milch", "native": "milk"]]
                            ]
                        ]
                    ]
                ]

                isLoading = true

                db.collection("users").document("63gFgHkgWoOOFnfbFtSuo7rzHTS2").setData(data, merge: true) { error in
                    if let error = error {
                        print("❌ Failed to save: \(error.localizedDescription)")
                    } else {
                        print("Words uploaded successfully")
                        Task {
                            await viewModel.fetchLanguageData()
                        }
                    }
                    isLoading = false
                }
            }
        }
    }

    private var savedWordsList: some View {
        VStack(spacing: 10) {
            SegmentedControlView(selectedSegment: $selectedSegment)

            ScrollView {
                ForEach(Array(getWords().enumerated()), id: \.offset) { index, word in
                    VStack {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 30, height: 30)

                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.black)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(word.target)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)

                                Text(word.native)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if index < getWords().count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.white : Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func getWords() -> [WordPair] {
        return selectedSegment == 0
            ? viewModel.savedWords?.knownWords ?? []
            : viewModel.savedWords?.unknownWords ?? []
    }
}


struct SegmentedControlView: View {
    @Binding var selectedSegment: Int
    let segments = ["Known", "Unknown"]

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / CGFloat(segments.count)

            ZStack(alignment: .leading) {
                // Background capsule
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appSecondaryColor)

                // Sliding indicator
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appPrimaryColor)
                    .frame(width: segmentWidth - 8, height: 36)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .offset(x: CGFloat(selectedSegment) * segmentWidth + 4)
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: selectedSegment
                    )

                // Labels
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { index in
                        Text(segments[index])
                            .font(
                                .system(
                                    size: 14,
                                    weight: selectedSegment == index
                                        ? .bold : .semibold
                                )
                            )
                            .frame(width: segmentWidth, height: 40)
                            .foregroundColor(
                                selectedSegment == index
                                    ? .white : .white.opacity(0.8)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSegment = index
                            }
                    }
                }
            }
        }
        .frame(height: 44)
        .padding(.bottom, 10)
    }
}

//struct PracticeView_Previews: PreviewProvider {
//    static var previews: some View {
//        PracticeView(userSession: userSession)
//    }
//}
