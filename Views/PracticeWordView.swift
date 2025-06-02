///
///  PracticeWordView.swift
///  LiNGUiD
///
///  Created by Dev Gohil on 5/28/25.
///

import SwiftUI

struct PracticeWordView: View {
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero

    let maxVisibleCards = 3

    @State private var knownWords: [String] = []
    @State private var unknownWords: [String] = []
    @State private var flashcardCache: [WordPair] = []

    @ObservedObject var savedWordsViewModel: SavedWordViewModel

    var knownWordsCount: Int {
        savedWordsViewModel.languageData[savedWordsViewModel.selectedLanguage]?
            .savedWords.knownWords.count ?? 0
    }

    var unknownWordsCount: Int {
        savedWordsViewModel.languageData[savedWordsViewModel.selectedLanguage]?
            .savedWords.unknownWords.count ?? 0
    }

    var body: some View {
        
        VStack(spacing: 20) {

            VStack {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                Color(
                                    red: 35 / 255,
                                    green: 35 / 255,
                                    blue: 35 / 255
                                )
                            )  // Background fill
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
                            .fill(
                                Color(
                                    red: 15 / 255,
                                    green: 15 / 255,
                                    blue: 15 / 255
                                )
                            )  // Background fill
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

                progressText.padding(.bottom)

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
        .background(Color.black)
        .onAppear {
            flashcardCache =
                savedWordsViewModel.languageData[
                    savedWordsViewModel.selectedLanguage
                ]?.savedWords.unknownWords ?? []
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
                    dragOffset =
                        isFlipped
                        ? CGSize(
                            width: -value.translation.width,
                            height: value.translation.height
                        ) : value.translation
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
            .stroke(Color.black, lineWidth: 2)
            .fill(
                isFlipped && index == currentIndex
                    ? Color.appSecondaryColor : Color.appPrimaryColor
            )
            .frame(width: 300, height: 500)
            .overlay(
                ZStack {
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
                x: visibleIndex == 0
                    ? dragOffset.width : CGFloat(-visibleIndex * 8),
                y: CGFloat(-visibleIndex * 8)
            )
            .zIndex(Double(maxVisibleCards - visibleIndex))
            .rotation3DEffect(
                .degrees(isFlipped && index == currentIndex ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(), value: currentIndex)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
    }

    var progressText: some View {
        if currentIndex == flashcardCache.count {

            if unknownWordsCount == 0 {
                return AnyView(
                    Text("Congratulations!")
                        .font(.title)
                        .foregroundColor(.white)
                )
            } else {
                return AnyView(
                    VStack(spacing: 20) {
                        Text("Well Done!")
                            .font(.title)
                            .foregroundColor(.white)

                        Text(
                            "You have \(unknownWordsCount) unknown words left.\nKeep practicing!"
                        )
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                    }
                )
            }

        } else {
            return AnyView(
                Text("Card \(currentIndex+1) of \(flashcardCache.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)
            )
        }
    }

    func handleSwipe() {
        let threshold: CGFloat = 100
        var swipingRight = dragOffset.width > threshold
        var swipingLeft = dragOffset.width < -threshold

        if isFlipped {
            swap(&swipingRight, &swipingLeft)
        }

        guard currentIndex < flashcardCache.count else { return }

        let currentWord = flashcardCache[currentIndex]

        if swipingRight {
            savedWordsViewModel.moveToKnown(word: currentWord)
            advance()
        } else if swipingLeft {
            advance()  // stay in unknown list
        } else {
            dragOffset = .zero
        }
    }

    func advance() {
        dragOffset = .zero
        isFlipped = false
        currentIndex += 1
    }
}
