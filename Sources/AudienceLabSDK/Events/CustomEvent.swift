import Foundation

struct CustomEvent {
    let name: String
    let params: [String: Any]
    let dedupeKey: String?

    var payload: [String: Any] {
        [
            "en": name,
            "pr": params
        ]
    }
}
