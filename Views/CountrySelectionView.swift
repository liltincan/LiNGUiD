import SwiftUI

struct CountrySelectionView: View {
    // MARK: – Inputs
    @Binding var selectedCountry: String?               // single selection
    var onContinue: (() -> Void)?                      // called when Continue is tapped

    // MARK: – State
    @State private var searchText = ""
    @State private var isSearching = false

    // MARK: – Data
    private let allCountries: [String] = [
        "Afghanistan","Albania","Algeria","Andorra","Angola","Antigua and Barbuda",
        "Argentina","Armenia","Australia","Austria","Azerbaijan","Bahamas","Bahrain",
        "Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bhutan","Bolivia",
        "Bosnia and Herzegovina","Botswana","Brazil","Brunei","Bulgaria","Burkina Faso",
        "Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic",
        "Chad","Chile","China","Colombia","Comoros","Congo (Congo‑Brazzaville)",
        "Costa Rica","Croatia","Cuba","Cyprus","Czech Republic (Czechia)",
        "Democratic Republic of the Congo","Denmark","Djibouti","Dominica",
        "Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea",
        "Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","Gabon",
        "Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea",
        "Guinea‑Bissau","Guyana","Haiti","Honduras","Hungary","Iceland","India",
        "Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan",
        "Jordan","Kazakhstan","Kenya","Kiribati","North Korea","South Korea","Kuwait",
        "Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya",
        "Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia",
        "Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico",
        "Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique",
        "Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua",
        "Niger","Nigeria","North Macedonia","Norway","Oman","Pakistan","Palau",
        "Panama","Papua New Guinea","Paraguay","Peru","Philippines","Poland","Portugal",
        "Qatar","Romania","Russia","Rwanda","Saint Kitts and Nevis","Saint Lucia",
        "Saint Vincent and the Grenadines","Samoa","San Marino","Sao Tome and Principe",
        "Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore",
        "Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Sudan",
        "Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syria","Taiwan",
        "Tajikistan","Tanzania","Thailand","Timor‑Leste","Togo","Tonga",
        "Trinidad and Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda",
        "Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay",
        "Uzbekistan","Vanuatu","Vatican City","Venezuela","Vietnam","Yemen","Zambia",
        "Zimbabwe"
    ]

    private var filteredCountries: [String] {
        // 1. Filter by search
        let base = searchText.isEmpty
            ? allCountries
            : allCountries.filter { $0.localizedCaseInsensitiveContains(searchText) }
        
        // 2. If one is selected, move it to front
        guard let sel = selectedCountry,
              let idx = base.firstIndex(of: sel) else {
            return base
        }
        
        var reordered = base
        reordered.remove(at: idx)
        reordered.insert(sel, at: 0)
        return reordered
    }

    // MARK: – Body
    var body: some View {
        VStack {
            VStack{
                HStack {
                    Text("Countries")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 15)
                    
                    Spacer()
                    
                    if isSearching {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(5)
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
                            .padding(.trailing, 15)
                    }
                }
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
                
                // ─── Country List ──────────────────────────────
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(filteredCountries.indices, id: \.self) { i in
                            let country = filteredCountries[i]

                            // ── Your row ──────────────────────────────────────────
                            HStack {
                                Image(systemName:
                                    selectedCountry == country
                                        ? "largecircle.fill.circle"
                                        : "circle"
                                )
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .bold))

                                Text(country)
                                    .foregroundColor(.white)

                                Spacer()
                            }
                            .padding(.vertical, 11.5)
                            .padding(.horizontal)
                            .font(.system(size: 17))
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                    if selectedCountry == country {
                                        selectedCountry = nil    // unselect if tapping the same one
                                    } else {
                                        selectedCountry = country
                                    }
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom))
                            ))
                            
                            // ── Divider under every row ─────────────
                            Divider()
                                .background(Color.white.opacity(1))
                                
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: filteredCountries)
                }
                .padding(.top, 8.5)
            }
            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
            .cornerRadius(8)
            .padding(.bottom, 36)
            
            if let text = selectedCountry, !text.isEmpty {
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
                .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

//// MARK: – Preview
//struct CountrySelectionView_Previews: PreviewProvider {
//    struct Wrapper: View {
//        @State private var country: String? = nil
//
//        var body: some View {
//            CountrySelectionView(
//                selectedCountry: $country,
//                onContinue: { print("Chosen:", country ?? "none") }
//            )
//        }
//    }
//
//    static var previews: some View {
//        Wrapper()
//            .preferredColorScheme(.dark)
//    }
//}
