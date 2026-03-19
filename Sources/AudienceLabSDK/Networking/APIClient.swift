import Foundation

enum APIClientError: Error {
    case invalidURL
    case apiKeyMissing
    case noData
    case server(statusCode: Int, message: String)
    case transport(Error)
}

final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    #if DEBUG
    var debugListener: ((RequestDebugEntry) -> Void)?
    #endif

    init(session: URLSession = .shared) {
        self.session = session
    }

    func post(path: String, body: [String: Any], completion: @escaping (Result<[String: Any], APIClientError>) -> Void) {
        request(path: path, method: "POST", body: body, completion: completion)
    }

    func get(path: String, completion: @escaping (Result<[String: Any], APIClientError>) -> Void) {
        request(path: path, method: "GET", body: nil, completion: completion)
    }

    private func request(path: String, method: String, body: [String: Any]?, completion: @escaping (Result<[String: Any], APIClientError>) -> Void) {
        guard let apiKey = SDKConfig.apiKey, !apiKey.isEmpty else {
            #if DEBUG
            emitDebug(path: path, body: body, statusCode: nil, responseBody: nil, success: false, errorMessage: "API key missing", apiKey: nil)
            #endif
            completion(.failure(.apiKeyMissing))
            return
        }
        let endpoint = Endpoints.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "geeklab-api-key")

        if let body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                #if DEBUG
                emitDebug(path: path, body: body, statusCode: nil, responseBody: nil, success: false, errorMessage: String(describing: error), apiKey: apiKey)
                #endif
                completion(.failure(.transport(error)))
                return
            }
        }

        session.dataTask(with: request) { data, response, error in
            if let error {
                #if DEBUG
                self.emitDebug(path: path, body: body, statusCode: (response as? HTTPURLResponse)?.statusCode, responseBody: data.flatMap { String(data: $0, encoding: .utf8) }, success: false, errorMessage: String(describing: error), apiKey: apiKey)
                #endif
                completion(.failure(.transport(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                self.emitDebug(path: path, body: body, statusCode: nil, responseBody: data.flatMap { String(data: $0, encoding: .utf8) }, success: false, errorMessage: "No HTTP response", apiKey: apiKey)
                #endif
                completion(.failure(.noData))
                return
            }
            let parsed = (data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) as? [String: Any] }) ?? [:]
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = parsed["message"] as? String ?? "Request failed"
                #if DEBUG
                self.emitDebug(path: path, body: body, statusCode: httpResponse.statusCode, responseBody: DebugUtilities.jsonString(parsed), success: false, errorMessage: message, apiKey: apiKey)
                #endif
                completion(.failure(.server(statusCode: httpResponse.statusCode, message: message)))
                return
            }
            #if DEBUG
            self.emitDebug(path: path, body: body, statusCode: httpResponse.statusCode, responseBody: DebugUtilities.jsonString(parsed), success: true, errorMessage: nil, apiKey: apiKey)
            #endif
            completion(.success(parsed))
        }.resume()
    }

    #if DEBUG
    private func emitDebug(
        path: String,
        body: [String: Any]?,
        statusCode: Int?,
        responseBody: String?,
        success: Bool,
        errorMessage: String?,
        apiKey: String?
    ) {
        guard let debugListener else { return }
        let normalizedPath = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestName = normalizedPath.replacingOccurrences(of: "/", with: "")
        let entry = RequestDebugEntry(
            requestName: requestName,
            path: normalizedPath,
            requestBody: body.map(DebugUtilities.jsonString),
            responseStatusCode: statusCode.map(NSNumber.init(value:)),
            responseBody: responseBody,
            success: success,
            errorMessage: errorMessage,
            authHeaderPreview: DebugUtilities.apiKeyPreview(apiKey)
        )

        DispatchQueue.main.async {
            debugListener(entry)
        }
    }
    #endif
}
