import SwiftUI

struct LanguageSelectionView: View {
    var onContinue: (([String]) -> Void)?
    let allLanguages = ["Arabic", "Chinese", "English", "French", "German", "Italian", "Portuguese", "Russian", "Spanish", "Afrikaans", "Armenian", "Azerbaijani", "Belarusian", "Bosnian", "Bulgarian", "Catalan", "Croatian", "Czech", "Danish", "Dutch", "Estonian", "Finnish", "Galician", "Greek", "Hebrew", "Hindi", "Hungarian", "Icelandic", "Indonesian", "Japanese", "Kannada", "Kazakh", "Korean", "Latvian", "Lithuanian", "Macedonian", "Malay", "Maori", "Marathi", "Nepali", "Norwegian", "Persian", "Polish", "Romanian", "Serbian", "Slovak", "Slovenian", "Swahili", "Swedish", "Tagalog", "Tamil", "Thai", "Turkish", "Ukrainian", "Urdu", "Vietnamese", "Welsh"]
    
    @State private var selectedLanguages = Set<String>()
    @State private var searchText = ""
    @State private var isSearching = false
    

    var filteredLanguages: [String] {
        if searchText.isEmpty {
            return allLanguages
        } else {
            return allLanguages.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header with Search
            VStack(spacing: 0) {
                HStack {
                    Text("Languages")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)

                    Spacer()

                    if isSearching {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .foregroundColor(.black)
                            .transition(.move(edge: .trailing))
                    }

                    Button(action: {
                        withAnimation {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = ""
                            }
                        }
                    }) {
                        Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 5)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)

                // Scrollable Language List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredLanguages, id: \.self) { language in
                            HStack {
                                Image(systemName: selectedLanguages.contains(language) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        toggleSelection(for: language)
                                    }
                                    .font(.system(size: 17, weight: .bold))

                                Text(language)
                                    .foregroundColor(.white)
                                    

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 25)
                            .font(.system(size: 17))
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: language)
                            }

                            if language != filteredLanguages.last {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .frame(maxHeight: 800)
            }
            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
            .cornerRadius(8)
            .padding(.horizontal)

            // Continue Button
            if !selectedLanguages.isEmpty {
                Button(action: {
                    onContinue?(Array(selectedLanguages));
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .transition(.opacity)
            }

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut, value: isSearching)
        .animation(.easeInOut, value: selectedLanguages)
    }

    private func toggleSelection(for language: String) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
        } else {
            selectedLanguages.insert(language)
        }
    }
}

//struct LanguageSelectionView_Previews: PreviewProvider {
//    static var previews: some View {
//        LanguageSelectionView()
//    }
//}
