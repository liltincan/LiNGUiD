import Foundation
import FirebaseAuth

class ReceiptValidator {
    static let shared = ReceiptValidator()
    private init() {}

    private let backendBaseURL = "https://makechicken.onrender.com"

    func fetchAppStoreReceipt() -> Data? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return nil
        }
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            return receiptData
        } catch {
            print("Couldn't read receipt data with error: " + error.localizedDescription)
            return nil
        }
    }

    func validateReceipt(receiptData: Data, uid: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let url = URL(string: "\(backendBaseURL)/validateReceipt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Receipt = receiptData.base64EncodedString()
        let body: [String: Any] = ["receiptData": base64Receipt, "uid": uid]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "ReceiptValidator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                completion(.success(json ?? [:]))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
