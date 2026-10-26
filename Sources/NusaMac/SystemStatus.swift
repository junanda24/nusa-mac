import Combine
import CoreWLAN
import Foundation
import IOKit.ps

/// Battery level / charging state (IOKit) and Wi-Fi SSID (CoreWLAN).
/// Every read is guarded: any failure produces nil/false, and the UI shows
/// a dash instead of inventing a value.
final class SystemStatus: ObservableObject {
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var wifiSSID: String?

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        batteryPercent = Self.readBatteryPercent()
        isCharging = Self.readIsCharging()
        wifiSSID = Self.readSSID()
    }

    // MARK: - Battery (IOKit)

    private static func powerSourceDescription() -> [String: Any]? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in list {
            let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue()
            if let dict = description as? [String: Any] {
                return dict
            }
        }
        return nil
    }

    private static func readBatteryPercent() -> Int? {
        guard let description = powerSourceDescription(),
              let current = description[kIOPSCurrentCapacityKey as String] as? Int,
              let max = description[kIOPSMaxCapacityKey as String] as? Int,
              max > 0 else { return nil }
        return Int(round(Double(current) / Double(max) * 100))
    }

    private static func readIsCharging() -> Bool {
        guard let description = powerSourceDescription(),
              let state = description[kIOPSPowerSourceStateKey as String] as? String else {
            return false
        }
        return state == (kIOPSACPowerValue as String)
    }

    // MARK: - Wi-Fi (CoreWLAN)

    private static func readSSID() -> String? {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else { return nil }
        return interface.ssid()
    }
}
