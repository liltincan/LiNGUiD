import SwiftUI

struct PracticeView: View {
    @State private var selectedSegment: Int = 0
    @State private var isActive: Bool = false
    @Environment(\.colorScheme) var colorScheme

    let germanWords = [
        "Hallo",
        "Tschüss",
        "Danke",
        "Bitte",
        "Wasser",
        "Buch",
        "Haus",
        "Freund",
        "Katze",
        "Essen",
    ]

    let englishTranslations = [
        "Hello",
        "Goodbye",
        "Thank you",
        "Please / You're welcome",
        "Water",
        "Book",
        "House",
        "Friend",
        "Cat",
        "Food",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AppTitleText(title: "PRACTICE")
                
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 2)
                        .fill(Color.appPrimaryColor)
                        .frame(width: 300, height: 150)
                        .offset(x: -20, y: -20)
                        .shadow(
                            color: .black.opacity(0.5),
                            radius: 2,
                            x: 0,
                            y: 2
                        )

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 2)
                        .fill(Color.appPrimaryColor)
                        .frame(width: 300, height: 150)
                        .offset(x: -10, y: -10)
                        .shadow(
                            color: .black.opacity(0.5),
                            radius: 2,
                            x: 0,
                            y: 2
                        )

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 2)
                        .fill(Color.appPrimaryColor)
                        .frame(width: 300, height: 150)
                        .shadow(
                            color: .black.opacity(0.5),
                            radius: 2,
                            x: 1,
                            y: 3
                        )
                        .overlay(
                            VStack(spacing:0){
                                Text("Tschüss")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Tap to practice")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .underline(true)
                            }
                        )
                }
                .padding(.top, 40)
                .padding(.bottom, 10)
                .padding(.leading, 30)
                .onTapGesture {
                    isActive = true
                }
                .navigationDestination(isPresented: $isActive) {
                        PracticeWordView()
                    }

                
                
                Text("Saved Words")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    SegmentedControlView(selectedSegment: $selectedSegment)

                    if selectedSegment == 0 {

                        ScrollView {
                            ForEach(Array(germanWords.enumerated()), id: \.1) {
                                index,
                                word in
                                VStack {
                                    HStack(spacing: 20) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray.opacity(0.1))
                                                .frame(width: 30, height: 30)

                                            Text("\(index + 1)")
                                                .font(
                                                    .system(
                                                        size: 16,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundColor(.black)
                                        }
                                        VStack(spacing: 3) {
                                            Text(word)
                                                .font(
                                                    .system(
                                                        size: 16,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(.black)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )

                                            Text("\(englishTranslations[index])")
                                                .font(
                                                    .system(
                                                        size: 14,
                                                        weight: .regular
                                                    )
                                                )
                                                .foregroundStyle(Color.gray)
                                                .multilineTextAlignment(.leading)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )
                                        }

                                    }.padding(.top, 3)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    if index < germanWords.count - 1 {
                                        Divider()
                                    }
                                }

                            }
                        }

                    } else {
                        ScrollView {
                            Text("Unknown Words")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding()
                .background(
                    colorScheme == .dark ? Color.white : Color.gray.opacity(0.1)
                )
                .cornerRadius(12)

            }
            .padding()
        }
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

struct PracticeView_Previews: PreviewProvider {
    static var previews: some View {
        PracticeView()
    }
}
