import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://analytics.geeklab.app")!
    static let auth = "/auth"
    static let verifyToken = "/verify-token"
    static let fetchToken = "/fetch-token"
    static let webhook = "/webhook"
    static let storeMetrics = "/store-metrics"
    static let checkDataCollectionStatus = "/CheckCollection"
}
