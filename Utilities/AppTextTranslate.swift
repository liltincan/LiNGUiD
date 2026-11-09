//
//  AppTextTranslate.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 6/11/25.
//

import Foundation

func translateTextV2(
    text: String,
    sourceLang: String,
    targetLang: String,
    completion: @escaping (String?) -> Void
) {
    let urlString = "https://translation.googleapis.com/language/translate/v2?key=xxxxxxxxxxxxxx"
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "q": text,
        "source": sourceLang,
        "target": targetLang,
        "format": "text"
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, _, error in
        guard
            error == nil,
            let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataDict = json["data"] as? [String: Any],
            let translations = dataDict["translations"] as? [[String: Any]],
            let translatedText = translations.first?["translatedText"] as? String
        else {
            completion(nil)
            return
        }

        completion(translatedText)
    }.resume()
}
