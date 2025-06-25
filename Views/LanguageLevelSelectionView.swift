import SwiftUI

struct LanguageLevelSelectionView: View {
    @Binding var selectedLevel: String?

    let levels = ["Just Starting", "Beginner", "Intermediate", "Advanced", "Expert"]
    let languageName: String
    var onContinue: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                Text("Select your \n level in \(languageName)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading){
                Text("Levels")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
            .cornerRadius(8)
            .padding(.top, 30)
            
            VStack(alignment: .leading){
                ForEach(levels, id: \.self) { level in
                    HStack {
                        Image(systemName: selectedLevel == level ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(level)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                    .cornerRadius(8)
//                    .onTapGesture {
//                        selectedLevel = level
//                    }
                    .onTapGesture {
                        if selectedLevel == level {
                            selectedLevel = nil
                        } else {
                            selectedLevel = level
                        }
                        print("Level '\(selectedLevel ?? "nil")' selected for \(languageName)")
                    }

                }
                
                Button(action: {
                    onContinue?()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                        .cornerRadius(8)
                }
                .padding(.top, 45)
                .opacity(selectedLevel != nil ? 1 : 0) // Hide/show without layout shift
                .disabled(selectedLevel == nil)        // Prevent interaction when not ready
                
                Spacer()
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())

    }
}

