import Foundation

#if DEBUG

@objcMembers
public final class IdentityDebugSnapshot: NSObject {
    public let settled: Bool
    public let idfvAvailable: Bool
    public let advertisingIdAvailable: Bool
    public let idfvPreview: String?
    public let advertisingIdPreview: String?
    public let limitAdTracking: NSNumber?

    public init(
        settled: Bool,
        idfvAvailable: Bool,
        advertisingIdAvailable: Bool,
        idfvPreview: String?,
        advertisingIdPreview: String?,
        limitAdTracking: NSNumber?
    ) {
        self.settled = settled
        self.idfvAvailable = idfvAvailable
        self.advertisingIdAvailable = advertisingIdAvailable
        self.idfvPreview = idfvPreview
        self.advertisingIdPreview = advertisingIdPreview
        self.limitAdTracking = limitAdTracking
    }
}

@objcMembers
public final class TokenDebugSnapshot: NSObject {
    public let hasValidToken: Bool
    public let creativeTokenPreview: String?
    public let lastFetchStatus: String
    public let lastAttemptAtMillis: NSNumber?
    public let attemptCount: Int
    public let nextRetryAtMillis: NSNumber?

    public init(
        hasValidToken: Bool,
        creativeTokenPreview: String?,
        lastFetchStatus: String,
        lastAttemptAtMillis: NSNumber?,
        attemptCount: Int,
        nextRetryAtMillis: NSNumber?
    ) {
        self.hasValidToken = hasValidToken
        self.creativeTokenPreview = creativeTokenPreview
        self.lastFetchStatus = lastFetchStatus
        self.lastAttemptAtMillis = lastAttemptAtMillis
        self.attemptCount = attemptCount
        self.nextRetryAtMillis = nextRetryAtMillis
    }
}

@objcMembers
public final class DeviceDebugSnapshot: NSObject {
    public let deviceName: String
    public let deviceModel: String
    public let osSystem: String
    public let windowWidth: Int
    public let windowHeight: Int
    public let dpi: Double
    public let timezoneIdentifier: String
    public let gpuVendor: String
    public let gpuRenderer: String
    public let batteryLevel: Double
    public let lowBatteryLevel: Bool
    public let installedFontCount: Int

    public init(
        deviceName: String,
        deviceModel: String,
        osSystem: String,
        windowWidth: Int,
        windowHeight: Int,
        dpi: Double,
        timezoneIdentifier: String,
        gpuVendor: String,
        gpuRenderer: String,
        batteryLevel: Double,
        lowBatteryLevel: Bool,
        installedFontCount: Int
    ) {
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.osSystem = osSystem
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.dpi = dpi
        self.timezoneIdentifier = timezoneIdentifier
        self.gpuVendor = gpuVendor
        self.gpuRenderer = gpuRenderer
        self.batteryLevel = batteryLevel
        self.lowBatteryLevel = lowBatteryLevel
        self.installedFontCount = installedFontCount
    }
}

@objcMembers
public final class QueueDebugEntry: NSObject {
    public let requestName: String
    public let eventId: String
    public let type: String
    public let payload: String
    public let queuedAtMillis: NSNumber

    public init(requestName: String, eventId: String, type: String, payload: String, queuedAtMillis: NSNumber) {
        self.requestName = requestName
        self.eventId = eventId
        self.type = type
        self.payload = payload
        self.queuedAtMillis = queuedAtMillis
    }
}

@objcMembers
public final class RequestDebugEntry: NSObject {
    public let requestName: String
    public let path: String
    public let requestBody: String?
    public let responseStatusCode: NSNumber?
    public let responseBody: String?
    public let success: Bool
    public let errorMessage: String?
    public let authHeaderPreview: String?

    public init(
        requestName: String,
        path: String,
        requestBody: String?,
        responseStatusCode: NSNumber?,
        responseBody: String?,
        success: Bool,
        errorMessage: String?,
        authHeaderPreview: String?
    ) {
        self.requestName = requestName
        self.path = path
        self.requestBody = requestBody
        self.responseStatusCode = responseStatusCode
        self.responseBody = responseBody
        self.success = success
        self.errorMessage = errorMessage
        self.authHeaderPreview = authHeaderPreview
    }
}

#endif
