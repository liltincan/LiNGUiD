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
        savedWordsViewModel.languageData[savedWordsViewModel.selectedLanguage]?.savedWords.knownWords.count ?? 0
    }

    var unknownWordsCount: Int {
        savedWordsViewModel.languageData[savedWordsViewModel.selectedLanguage]?.savedWords.unknownWords.count ?? 0
    }
    
    


    var body: some View {
        VStack(spacing: 20) {
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Known words: \(knownWordsCount)")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Unknown words: \(unknownWordsCount)")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 60)
            .padding(.leading, 20)
            
            VStack(spacing: 20) {
                progressText.padding(.bottom)

                ZStack {
                    ForEach(Array(flashcardCache.enumerated()), id: \.offset) { index, word in
                        let visibleIndex = index - currentIndex
                        if visibleIndex >= 0 && visibleIndex < maxVisibleCards {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 2)
                                .fill(
                                    isFlipped && index == currentIndex ? Color.appSecondaryColor : Color.appPrimaryColor)
                                .frame(width: 300, height: 150)
                                .overlay(
                                    ZStack {
                                        // Front text
                                        Text(flashcardCache[index].target)
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(!isFlipped || index != currentIndex ? 1 : 0)

                                        // Back text
                                        Text(flashcardCache[index].native)
                                            .font(.system(size: 30, weight: .medium))
                                            .foregroundColor(.white)
                                            .opacity(isFlipped && index == currentIndex ? 1 : 0)
                                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                                    }
                                    .animation(nil, value: isFlipped)
                                )




                                .offset(
                                    x: visibleIndex == 0 ? dragOffset.width : CGFloat(-visibleIndex * 8),
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
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                                dragOffset = isFlipped ? CGSize(width: -value.translation.width, height: value.translation.height) : value.translation
                            }
                        .onEnded { _ in handleSwipe() }
                )
                .onTapGesture {
                    withAnimation { isFlipped.toggle() }
                }

                if currentIndex < flashcardCache.count {
                    Text("Tap to flip")
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

        } 
        .padding()
        .background(Color.black)
        .task {
            flashcardCache = savedWordsViewModel.languageData[savedWordsViewModel.selectedLanguage]?.savedWords.unknownWords ?? []
        }

    }

    var progressText: some View {
        if currentIndex == flashcardCache.count {
            return Text("Congratulations!")
                .font(.title)
                .foregroundColor(.white)
        } else {
            return Text("\(currentIndex)/\(flashcardCache.count)")
                .font(.subheadline)
                .foregroundColor(.white)
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
            advance() // stay in unknown list
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

struct PracticeWordView_Previews: PreviewProvider {
    static var previews: some View {
        PracticeWordView(savedWordsViewModel: SavedWordViewModel())
    }
}
