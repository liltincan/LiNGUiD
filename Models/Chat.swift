//
//  Chat.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 6/23/25.
//

import Firebase
import FirebaseFirestore

//MARK: - Model for Users Friends Information
struct Chat: Identifiable {
    let id: String
    let participantIDs: [String]
    var lastMessage: String
    var username: String
    var status: String
    var country: String
    var profileimage: String
    var isActive: Bool
    var lastSeen: Date?
    var lastMessageTimestamp: Date?
    var nativeLanguage: String
    var learningLanguage: String
    var comprehensionLevel: Int
    
    //this will then be used in the view to get the flag emoji (computed property that will be used in view)
    var flag: String {
        flagEmoji(for: country)
    }
}
//precondition: none
//postcondition: going to convert the field 'country' to a flag emoji
func flagEmoji(for country: String) -> String {
    let base : UInt32 = 127397
    let countryCode = countryCodeFromCountryName(country)
    guard countryCode.count == 2 else { return "" }
    var scalarView = String.UnicodeScalarView()
    for scalar in countryCode.uppercased().unicodeScalars {
        if let scalarValue = UnicodeScalar(base + scalar.value) {
            scalarView.append(scalarValue)
        }
    }
    return String(scalarView)
}
//precondition: none
//postcondition: going to map the country  name with short term such as United States-> US
func countryCodeFromCountryName(_ name: String) -> String {
    let countryMapping: [String: String] = [
        "Afghanistan": "AF", "Albania": "AL", "Algeria": "DZ", "Andorra": "AD",
        "Angola": "AO", "Antigua and Barbuda": "AG", "Argentina": "AR", "Armenia": "AM",
        "Australia": "AU", "Austria": "AT", "Azerbaijan": "AZ", "Bahamas": "BS",
        "Bahrain": "BH", "Bangladesh": "BD", "Barbados": "BB", "Belarus": "BY",
        "Belgium": "BE", "Belize": "BZ", "Benin": "BJ", "Bhutan": "BT",
        "Bolivia": "BO", "Bosnia and Herzegovina": "BA", "Botswana": "BW", "Brazil": "BR",
        "Brunei": "BN", "Bulgaria": "BG", "Burkina Faso": "BF", "Burundi": "BI",
        "Cambodia": "KH", "Cameroon": "CM", "Canada": "CA", "Cape Verde": "CV",
        "Central African Republic": "CF", "Chad": "TD", "Chile": "CL", "China": "CN",
        "Colombia": "CO", "Comoros": "KM", "Costa Rica": "CR", "Croatia": "HR",
        "Cuba": "CU", "Cyprus": "CY", "Czech Republic": "CZ", "Denmark": "DK",
        "Djibouti": "DJ", "Dominica": "DM", "Dominican Republic": "DO", "Ecuador": "EC",
        "Egypt": "EG", "El Salvador": "SV", "Equatorial Guinea": "GQ", "Eritrea": "ER",
        "Estonia": "EE", "Eswatini": "SZ", "Ethiopia": "ET", "Fiji": "FJ",
        "Finland": "FI", "France": "FR", "Gabon": "GA", "Gambia": "GM",
        "Georgia": "GE", "Germany": "DE", "Ghana": "GH", "Greece": "GR",
        "Grenada": "GD", "Guatemala": "GT", "Guinea": "GN", "Guinea-Bissau": "GW",
        "Guyana": "GY", "Haiti": "HT", "Honduras": "HN", "Hungary": "HU",
        "Iceland": "IS", "India": "IN", "Indonesia": "ID", "Iran": "IR",
        "Iraq": "IQ", "Ireland": "IE", "Israel": "IL", "Italy": "IT",
        "Ivory Coast": "CI", "Jamaica": "JM", "Japan": "JP", "Jordan": "JO",
        "Kazakhstan": "KZ", "Kenya": "KE", "Kiribati": "KI", "Kuwait": "KW",
        "Kyrgyzstan": "KG", "Laos": "LA", "Latvia": "LV", "Lebanon": "LB",
        "Lesotho": "LS", "Liberia": "LR", "Libya": "LY", "Liechtenstein": "LI",
        "Lithuania": "LT", "Luxembourg": "LU", "Madagascar": "MG", "Malawi": "MW",
        "Malaysia": "MY", "Maldives": "MV", "Mali": "ML", "Malta": "MT",
        "Marshall Islands": "MH", "Mauritania": "MR", "Mauritius": "MU", "Mexico": "MX",
        "Micronesia": "FM", "Moldova": "MD", "Monaco": "MC", "Mongolia": "MN",
        "Montenegro": "ME", "Morocco": "MA", "Mozambique": "MZ", "Myanmar": "MM",
        "Namibia": "NA", "Nauru": "NR", "Nepal": "NP", "Netherlands": "NL",
        "New Zealand": "NZ", "Nicaragua": "NI", "Niger": "NE", "Nigeria": "NG",
        "North Korea": "KP", "North Macedonia": "MK", "Norway": "NO", "Oman": "OM",
        "Pakistan": "PK", "Palau": "PW", "Panama": "PA", "Papua New Guinea": "PG",
        "Paraguay": "PY", "Peru": "PE", "Philippines": "PH", "Poland": "PL",
        "Portugal": "PT", "Qatar": "QA", "Romania": "RO", "Russia": "RU",
        "Rwanda": "RW", "Saint Kitts and Nevis": "KN", "Saint Lucia": "LC",
        "Saint Vincent and the Grenadines": "VC", "Samoa": "WS", "San Marino": "SM",
        "Sao Tome and Principe": "ST", "Saudi Arabia": "SA", "Senegal": "SN",
        "Serbia": "RS", "Seychelles": "SC", "Sierra Leone": "SL", "Singapore": "SG",
        "Slovakia": "SK", "Slovenia": "SI", "Solomon Islands": "SB", "Somalia": "SO",
        "South Africa": "ZA", "South Korea": "KR", "South Sudan": "SS", "Spain": "ES",
        "Sri Lanka": "LK", "Sudan": "SD", "Suriname": "SR", "Sweden": "SE",
        "Switzerland": "CH", "Syria": "SY", "Taiwan": "TW", "Tajikistan": "TJ",
        "Tanzania": "TZ", "Thailand": "TH", "Timor-Leste": "TL", "Togo": "TG",
        "Tonga": "TO", "Trinidad and Tobago": "TT", "Tunisia": "TN", "Turkey": "TR",
        "Turkmenistan": "TM", "Tuvalu": "TV", "Uganda": "UG", "Ukraine": "UA",
        "United Arab Emirates": "AE", "United Kingdom": "GB", "United States": "US",
        "Uruguay": "UY", "Uzbekistan": "UZ", "Vanuatu": "VU", "Vatican City": "VA",
        "Venezuela": "VE", "Vietnam": "VN", "Yemen": "YE", "Zambia": "ZM", "Zimbabwe": "ZW"
    ]
    return countryMapping[name] ?? ""
}

//MARK: - Model for Chat Messages
struct ChatMessages: Identifiable, Equatable {
    var text: String
    //who is replying
    var isFromCurrentUser: Bool
    var isRead: Bool
    var timestamp: Date?
    var repliedToText: String?
    var isLiked: Bool = false
    var documentID: String
    //this will be the translation to go back to users native language
    var translatedText: String? = nil
    var id: String { documentID }
}
//MARK: - Model for which Conversation it is with their messages
struct ChatConversation: Identifiable, Equatable {
    let id = UUID()
    var friend: Chat
    var messages: [ChatMessages]
    
    static func == (lhs: ChatConversation, rhs: ChatConversation) -> Bool {
        lhs.id == rhs.id &&
        lhs.friend.id == rhs.friend.id &&
        lhs.messages == rhs.messages
    }
}
//MARK: - Focus Field to control the keyboard typing
enum FocusField {
    case sendMessage, searchUsername
}
//MARK: - Extension so i can reuse the data in chat conversation
extension ChatConversation {
    //checks for which message is not read
    var hasUnreadMessages: Bool {
        messages.contains { !$0.isFromCurrentUser && !$0.isRead }
    }
    //checks for the last message then determines if it is read, delivered, or sent
    var lastMessageStatus: String {
        guard let last = messages.last else { return "" }
        return last.isFromCurrentUser ? (last.isRead ? "read" : "sent") : ""
    }
    //checks how many unread messages it has and returns an int
    var unreadCount: Int {
        messages.filter { !$0.isFromCurrentUser && !$0.isRead }.count
    }
    
}
//MARK: - Extension will allow me to get the users ID participant that is not the current users
extension Chat {
    func otherUserID(currentUserID: String) -> String? {
        //look through the array from start and find the first userID that will satisfy the closure inside the 'where' (will return the other users ids)
        participantIDs.first(where: { $0 != currentUserID })
    }
}
//MARK: - This will be the path to user when we are navigating to different destination (used in the main view chatlistview)
enum ChatRoute: Hashable {
    case chatDetail(String), discovery, profile(String)
}

//MARK: - Full name of languages
struct LanguageUtils {
    static let languageMap: [String: String] = [
        "af": "Afrikaans", "am": "Amharic", "ar": "Arabic", "az": "Azerbaijani",
        "be": "Belarusian", "bg": "Bulgarian", "bn": "Bengali", "bs": "Bosnian",
        "ca": "Catalan", "ceb": "Cebuano", "cs": "Czech", "cy": "Welsh",
        "da": "Danish", "de": "German", "el": "Greek", "en": "English",
        "eo": "Esperanto", "es": "Spanish", "et": "Estonian", "eu": "Basque",
        "fa": "Persian", "fi": "Finnish", "fil": "Filipino", "fj": "Fijian",
        "fr": "French", "fy": "Frisian", "ga": "Irish", "gd": "Scots Gaelic",
        "gl": "Galician", "gu": "Gujarati", "ha": "Hausa", "haw": "Hawaiian",
        "he": "Hebrew", "hi": "Hindi", "hmn": "Hmong", "hr": "Croatian",
        "ht": "Haitian Creole", "hu": "Hungarian", "hy": "Armenian",
        "id": "Indonesian", "ig": "Igbo", "is": "Icelandic", "it": "Italian",
        "iw": "Hebrew", "ja": "Japanese", "jw": "Javanese", "ka": "Georgian",
        "kk": "Kazakh", "km": "Khmer", "kn": "Kannada", "ko": "Korean",
        "ku": "Kurdish", "ky": "Kyrgyz", "la": "Latin", "lb": "Luxembourgish",
        "lo": "Lao", "lt": "Lithuanian", "lv": "Latvian", "mg": "Malagasy",
        "mi": "Maori", "mk": "Macedonian", "ml": "Malayalam", "mn": "Mongolian",
        "mr": "Marathi", "ms": "Malay", "mt": "Maltese", "my": "Burmese",
        "ne": "Nepali", "nl": "Dutch", "no": "Norwegian", "ny": "Nyanja",
        "pa": "Punjabi", "pl": "Polish", "ps": "Pashto", "pt": "Portuguese",
        "ro": "Romanian", "ru": "Russian", "rw": "Kinyarwanda", "sd": "Sindhi",
        "si": "Sinhala", "sk": "Slovak", "sl": "Slovenian", "sm": "Samoan",
        "sn": "Shona", "so": "Somali", "sq": "Albanian", "sr": "Serbian",
        "st": "Sesotho", "su": "Sundanese", "sv": "Swedish", "sw": "Swahili",
        "ta": "Tamil", "te": "Telugu", "tg": "Tajik", "th": "Thai", "tk": "Turkmen",
        "tl": "Tagalog", "tr": "Turkish", "tt": "Tatar", "ug": "Uyghur",
        "uk": "Ukrainian", "ur": "Urdu", "uz": "Uzbek", "vi": "Vietnamese",
        "xh": "Xhosa", "yi": "Yiddish", "yo": "Yoruba", "zh": "Chinese", "zu": "Zulu"
    ]
    static func fullName(for code: String) -> String {
        return languageMap[code.lowercased()] ?? code.capitalized
    }
    static var sortedLanguages: [(code: String, name: String)] {
        languageMap.map { ($0.key, $0.value) }
            .sorted { $0.name < $1.name }
    }
}
