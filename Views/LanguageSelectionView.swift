import SwiftUI

struct LanguageSelectionView: View {
    var onContinue: (([String]) -> Void)?
    let allLanguages = ["Arabic", "Chinese", "English", "French", "German", "Italian", "Portuguese", "Russian", "Spanish", "Afrikaans", "Armenian", "Azerbaijani", "Belarusian", "Bosnian", "Bulgarian", "Catalan", "Croatian", "Czech", "Danish", "Dutch", "Estonian", "Finnish", "Galician", "Greek", "Hebrew", "Hindi", "Hungarian", "Icelandic", "Indonesian", "Japanese", "Kannada", "Kazakh", "Korean", "Latvian", "Lithuanian", "Macedonian", "Malay", "Maori", "Marathi", "Nepali", "Norwegian", "Persian", "Polish", "Romanian", "Serbian", "Slovak", "Slovenian", "Swahili", "Swedish", "Tagalog", "Tamil", "Thai", "Turkish", "Ukrainian", "Urdu", "Vietnamese", "Welsh"]
    let selectionLimit: Int
    
    @Binding var selectedLanguages: Set<String>
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showCustomAlert = false
    var excludeLanguages: [String] = []
    var onDeselect: ((String) -> Void)? = nil

    
    var filteredLanguages: [String] {
        let languages = allLanguages.filter { !excludeLanguages.contains($0) }
        let searchFilteredLanguages: [String]
        
        if searchText.isEmpty {
            searchFilteredLanguages = languages
        } else {
            searchFilteredLanguages = languages.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort languages: selected ones first, then unselected ones
        let selectedFiltered = searchFilteredLanguages.filter { selectedLanguages.contains($0) }
        let unselectedFiltered = searchFilteredLanguages.filter { !selectedLanguages.contains($0) }
        
        return selectedFiltered + unselectedFiltered
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
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLanguages, id: \.self) { language in
                            HStack {
                                Image(systemName: selectedLanguages.contains(language) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                            toggleSelection(for: language)
                                        }
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
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                    toggleSelection(for: language)
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom))
                            ))

                            if language != filteredLanguages.last {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: selectedLanguages)
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
        .overlay(
            Group {
                if showCustomAlert {
                    ZStack {
                        // Dimmed blurred background
                        Color.black.opacity(0.8)
                            .ignoresSafeArea()
                            .transition(.opacity)
                        
                        // Alert box
                        VStack(spacing: 20) {
                            Text("Selection Limit Reached")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("You can only select up to \(selectionLimit) languages")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                withAnimation {
                                    showCustomAlert = false
                                }
                            }) {
                                Text("OK")
                                    .frame(minWidth: 250)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(Color(red: 124/255, green: 58/255, blue: 237/255))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding(.horizontal, 40)
                        .transition(.scale)
                        .offset(y: -100)
                    }
                    .animation(.easeInOut, value: showCustomAlert)
                }
            }
        )
        .animation(.easeInOut, value: isSearching)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: selectedLanguages)
    }
    

    private func toggleSelection(for language: String) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
            onDeselect?(language)
        } else {
            if selectedLanguages.count >= selectionLimit {
                withAnimation {
                    showCustomAlert = true
                }
            } else {
                selectedLanguages.insert(language)
            }
        }
    }
}
