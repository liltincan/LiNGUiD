///
///  PracticeWordView.swift
///  LiNGUiD
///
///  Created by Dev Gohil on 5/28/25.
///

import SwiftUI

struct PracticeWordView: View {
    @EnvironmentObject var userSession: UserSessionViewModel
    @ObservedObject var savedWordsViewModel: SavedWordViewModel

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var reload: Bool = false
    @State private var totalUnknownWords: Int = 0

    let maxVisibleCards = 3

    @State private var knownWords: [String] = []
    @State private var unknownWords: [String] = []
    @State private var flashcardCache: [WordPair] = []
    @State private var viewID = UUID()
    @State private var swipeDirection: SwipeDirection? = nil

    enum SwipeDirection {
        case left, right
    }

    var knownWordsCount: Int {
        savedWordsViewModel.savedWords?.knownWords.count ?? 0
    }

    var unknownWordsCount: Int {
        savedWordsViewModel.savedWords?.unknownWords.count ?? 0
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1.5)
                            )
                            .frame(width: 40, height: 35)

                        Text("\(unknownWordsCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                    Spacer()
                    Text("Swipe")
                        .font(.system(size: 26, weight: .bold))
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1.5)
                            )
                            .frame(width: 40, height: 35)

                        Text("\(knownWordsCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.green)
                    }
                }
                .padding(20)
            }

            Spacer()

            VStack(spacing: 20) {
                flashcardStack()
                progressText(with: UUID()).padding(.bottom)
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .navigationTitle("FLASHCARDS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FLASHCARDS")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        //        .background(Color.black)
        .onAppear {
            flashcardCache =
                savedWordsViewModel.savedWords?.unknownWords ?? []

            totalUnknownWords =
                savedWordsViewModel.savedWords?.unknownWords.count ?? 0
        }
    }

    private func flashcardStack() -> some View {
        ZStack {
            ForEach(Array(flashcardCache.enumerated()), id: \.offset) {
                index,
                word in
                let visibleIndex = index - currentIndex
                if visibleIndex >= 0 && visibleIndex < maxVisibleCards {
                    flashcardView(
                        for: word,
                        at: index,
                        visibleIndex: visibleIndex
                    )
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let offset =
                        isFlipped
                        ? CGSize(
                            width: -value.translation.width,
                            height: value.translation.height
                        )
                        : value.translation
                    dragOffset = offset

                    // Direction preview based on horizontal intent
                    if isFlipped {
                        if offset.width < -40 {
                            swipeDirection = .right
                        } else if offset.width > 40 {
                            swipeDirection = .left
                        } else {
                            swipeDirection = nil
                        }
                    } else {
                        if offset.width > 40 {
                            swipeDirection = .right
                        } else if offset.width < -40 {
                            swipeDirection = .left
                        } else {
                            swipeDirection = nil
                        }
                    }
                }

                .onEnded { _ in handleSwipe() }
        )
        .onTapGesture {
            withAnimation { isFlipped.toggle() }
        }
    }

    private func flashcardView(
        for word: WordPair,
        at index: Int,
        visibleIndex: Int
    ) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                currentIndex == index
                    ? (swipeDirection == .right
                        ? Color.green
                        : swipeDirection == .left ? Color.red : Color.black)
                    : Color.black,
                lineWidth: 3
            )
            .fill(
                isFlipped && index == currentIndex
                    ? Color.appSecondaryColor : Color.appPrimaryColor
            )
            .frame(width: 300, height: 500)
            .overlay(
                ZStack {
                    if swipeDirection != nil && index == currentIndex {

                        VStack {
                            Spacer().frame(height: 20)

                            swipeTextView(
                                swipeDirection: swipeDirection,
                                index: index
                            )

                            Spacer()
                        }

                    }
                    Text(word.target)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(!isFlipped || index != currentIndex ? 1 : 0)

                    Text(word.native)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                        .opacity(isFlipped && index == currentIndex ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(180),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
                .animation(nil, value: isFlipped)
            )
            .offset(
                x: visibleIndex == 0 ? dragOffset.width : CGFloat(-visibleIndex * 8),
                y: visibleIndex == 0 ? dragOffset.height : CGFloat(-visibleIndex * 8)
            )
            .rotationEffect(
                visibleIndex == 0 ? .degrees(Double(dragOffset.width / 15)) : .degrees(0)
            )
//            .rotation3DEffect(
//                .degrees(Double(dragOffset.height / 15)),
//                axis: (x: 1.0, y: 0.0, z: 0.0)
//            )

            .zIndex(Double(maxVisibleCards - visibleIndex))
            .rotation3DEffect(
                .degrees(isFlipped && index == currentIndex ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(), value: currentIndex)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
    }

    func swipeTextView(swipeDirection: SwipeDirection?, index: Int) -> some View
    {
        let statusText: String
        let statusColor: Color
        let textAlignment: Alignment

        switch swipeDirection {
        case .right:
            statusText = "Know"
            statusColor = .green
            textAlignment = .leading
        case .left:
            statusText = "Still Learning"
            statusColor = .red
            textAlignment = .trailing
        default:
            statusText = ""
            statusColor = .clear
            textAlignment = .center
        }

        return Text(statusText)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity, alignment: textAlignment)
            .padding(.horizontal, 30)
            .rotation3DEffect(
                .degrees(isFlipped && index == currentIndex ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
    }

    func progressText(with newID: UUID) -> some View {
        if currentIndex == flashcardCache.count {
            if unknownWordsCount == 0 {
                return AnyView(
                    VStack(spacing: 0) {
                        Text("Congratulations!")
                            .font(.title)
                            .foregroundColor(.white)

                        Text("You have learned \(totalUnknownWords) new words!")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                    }
                )
            } else {
                return AnyView(
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            Text("Well Done!")
                                .font(.title)
                                .foregroundColor(.white)

                            Text(
                                "You have \(unknownWordsCount) unknown words left!"
                            )
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                        }

                        Button(action: {
                            viewID = newID
                            currentIndex = 0
                            isFlipped = false
                            dragOffset = .zero
                            flashcardCache =
                                savedWordsViewModel.savedWords?.unknownWords
                                ?? []
                        }) {
                            Text("Keep practicing")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(Color.appPrimaryColor)
                                .cornerRadius(10)
                        }
                    }
                )
            }
        } else {
            return AnyView(
                Text("Card \(currentIndex + 1) of \(flashcardCache.count)")
                    .font(.system(size: 14, weight: .regular))
                //                    .foregroundColor(.white)
            )
        }
    }
    
    func handleSwipe() {
        let horizontal = dragOffset.width
        let vertical = dragOffset.height

        // Use angle or dominance to determine intent
        let threshold: CGFloat = 80
        let isHorizontalSwipe = abs(horizontal) > abs(vertical)

        guard currentIndex < flashcardCache.count else { return }
        let currentWord = flashcardCache[currentIndex]

        if isHorizontalSwipe && horizontal > threshold {
            swipeDirection = .right
            if let userId = userSession.currentUser?.id {
                savedWordsViewModel.moveToKnown(
                    word: currentWord,
                    userId: userId
                )
            }
            advance()
        } else if isHorizontalSwipe && horizontal < -threshold {
            swipeDirection = .left
            advance()
        } else {
            dragOffset = .zero
            swipeDirection = nil
        }
    }

    func advance() {
        dragOffset = .zero
        isFlipped = false
        currentIndex += 1
        swipeDirection = nil
    }
}
