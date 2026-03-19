import Foundation

struct AdEvent {
    let adId: String
    let name: String
    let source: String
    let watchTime: Double
    let reward: Bool
    let mediaSource: String
    let channel: String
    let value: Double
    let currency: String
    let dedupeKey: String?

    func payload(totalAdValue: Double) -> [String: Any] {
        [
            "ad_id": adId,
            "name": name,
            "source": source,
            "watch_time": watchTime,
            "reward": reward,
            "media_source": mediaSource,
            "channel": channel,
            "value": CurrencyValue.decimalNumber(from: value),
            "currency": currency,
            "total_ad_value": CurrencyValue.decimalNumber(from: totalAdValue)
        ]
    }
}
