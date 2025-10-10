import Foundation
import FirebaseAuth

class ReceiptValidator {
    static let shared = ReceiptValidator()
    private init() {}

    // Replace with your actual backend URL
    private let backendURL = "https://your-backend-domain.com/api/iap/validateReceipt"
    // Replace with your App Store shared secret
    private let sharedSecret = "your_app_store_shared_secret"

    func validateReceipt(receiptData: Data, uid: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: backendURL) else {
            completion(.failure(NSError(domain: "ReceiptValidator", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])))
            return
        }

        let base64Receipt = receiptData.base64EncodedString()
        let requestBody: [String: Any] = [
            "receipt_data": base64Receipt,
            "shared_secret": sharedSecret,
            "uid": uid
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "ReceiptValidator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "ReceiptValidator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func fetchAppStoreReceipt() -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData
    }
}
