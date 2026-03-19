import Foundation
import UIKit
import Metal

struct DeviceInfo {
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let screenWidth: Int
    let screenHeight: Int
    let dpi: Double
    let gpuVersion: String
    let gpuVendor: String
    let gpuRenderer: String
    let gpuContent: String?
    let batteryLevel: Double
    let lowBattery: Bool
    let installedFonts: [String]
}

enum DeviceInfoCollector {
    static func collect() -> DeviceInfo {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        let dpi = Double(scale * 163.0)
        let device = UIDevice.current
        let batteryLevel = Double(device.batteryLevel)
        let lowBattery = batteryLevel >= 0 && batteryLevel <= 0.2
        let metalDevice = MTLCreateSystemDefaultDevice()
        let renderer = metalDevice?.name ?? "unknown"
        let gpuVersion = metalDevice == nil ? "unknown" : "Metal"
        let gpuVendor = metalDevice == nil ? "unknown" : "Apple"
        let gpuContent = metalDevice.map { String(describing: $0) }

        return DeviceInfo(
            deviceName: device.name,
            deviceModel: machineIdentifier(),
            osVersion: "\(device.systemName) \(device.systemVersion)",
            screenWidth: width,
            screenHeight: height,
            dpi: dpi,
            gpuVersion: gpuVersion,
            gpuVendor: gpuVendor,
            gpuRenderer: renderer,
            gpuContent: gpuContent,
            batteryLevel: batteryLevel,
            lowBattery: lowBattery,
            installedFonts: UIFont.familyNames.sorted()
        )
    }

    #if DEBUG
    static func debugSnapshot() -> DeviceDebugSnapshot {
        let info = collect()
        return DeviceDebugSnapshot(
            deviceName: info.deviceName,
            deviceModel: info.deviceModel,
            osSystem: info.osVersion,
            windowWidth: info.screenWidth,
            windowHeight: info.screenHeight,
            dpi: info.dpi,
            timezoneIdentifier: DateUtils.timezoneIdentifier(),
            gpuVendor: info.gpuVendor,
            gpuRenderer: info.gpuRenderer,
            batteryLevel: info.batteryLevel,
            lowBatteryLevel: info.lowBattery,
            installedFontCount: info.installedFonts.count
        )
    }
    #endif

    private static func machineIdentifier() -> String {
        if let simulatedModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !simulatedModel.isEmpty {
            return simulatedModel
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
