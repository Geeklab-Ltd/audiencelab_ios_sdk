import Foundation

struct PurchaseEvent {
    let itemId: String
    let itemName: String
    let value: Double
    let currency: String
    let status: String
    let transactionId: String?
    let dedupeKey: String?

    func payload(totalPurchaseValue: Double) -> [String: Any] {
        var payload: [String: Any] = [
            "item_id": itemId,
            "item_name": itemName,
            "value": CurrencyValue.decimalNumber(from: value),
            "currency": currency,
            "status": status,
            "total_purchase_value": CurrencyValue.decimalNumber(from: totalPurchaseValue)
        ]
        if let transactionId, !transactionId.isEmpty {
            payload["tr_id"] = transactionId
        }
        return payload
    }

    var shouldIncrementTotalValue: Bool {
        let normalized = status.lowercased()
        return normalized == "completed" || normalized == "success"
    }
}
