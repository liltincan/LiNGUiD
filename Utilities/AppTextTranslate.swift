//
//  AppTextTranslate.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 6/11/25.
//

import Foundation

func translateWithMyMemory(text: String, from source: String, to target: String, completion: @escaping (String?, String?) -> Void) {
    let escapedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://api.mymemory.translated.net/get?q=\(escapedText)&langpair=\(source)|\(target)"

    guard let url = URL(string: urlString) else {
        completion(nil, nil)
        return
    }

    URLSession.shared.dataTask(with: url) { data, _, error in
        guard let data = data, error == nil else {
            completion(nil, nil)
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["responseData"] as? [String: Any],
               let matches = json["matches"] as? [[String: Any]] {
                
                
                let filtered = matches.filter {
                    guard
                        let matchScore = $0["match"] as? Double,
                        let translation = $0["translation"] as? String
                    else { return false }

                    return matchScore >= 0.7 && !translation.lowercased().contains("google tranlator")
                }

                let bestTranslation = filtered.first?["translation"] as? String
                let source = filtered.first?["created-by"] as? String ?? "unknown"
                
                
                let safeResult = bestTranslation ?? (responseData["translatedText"] as? String ?? "N/A")
                completion(safeResult, source)

            } else {
                completion(nil, nil)
            }
        } catch {
            completion(nil, nil)
        }
    }.resume()
}
