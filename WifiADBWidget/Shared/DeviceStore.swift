import Foundation
import WidgetKit

struct DeviceInfo: Codable, Equatable {
    let addr: String
    let model: String
    let state: String  // "connected", "offline", "not connected", …
    let attached: Bool
    var title: String { model.isEmpty ? addr : "\(model)  \(addr)" }
}

struct DeviceCommand: Codable, Equatable {
    let action: String  // "reconnect" or "disconnect"
    let addr: String
}

/// The widget cannot run adb, so the app publishes the device list here and the widget's
/// buttons queue commands that the app picks up on its next poll.
enum DeviceStore {
    private static let devicesKey = "devices"
    private static let commandsKey = "deviceCommands"

    static func loadDevices() -> [DeviceInfo] {
        guard let data = sharedDefaults.data(forKey: devicesKey) else { return [] }
        return (try? sharedDecoder.decode([DeviceInfo].self, from: data)) ?? []
    }

    /// Stores the list and refreshes the widget only when something changed.
    static func saveDevices(_ devices: [DeviceInfo]) {
        guard devices != loadDevices() else { return }
        sharedDefaults.set(try? sharedEncoder.encode(devices), forKey: devicesKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func enqueue(_ command: DeviceCommand) {
        var queue = loadCommands()
        if !queue.contains(command) { queue.append(command) }
        sharedDefaults.set(try? sharedEncoder.encode(queue), forKey: commandsKey)
    }

    /// Removes and returns the oldest queued command.
    static func takeCommand() -> DeviceCommand? {
        var queue = loadCommands()
        guard !queue.isEmpty else { return nil }
        let first = queue.removeFirst()
        sharedDefaults.set(try? sharedEncoder.encode(queue), forKey: commandsKey)
        return first
    }

    private static func loadCommands() -> [DeviceCommand] {
        guard let data = sharedDefaults.data(forKey: commandsKey) else { return [] }
        return (try? sharedDecoder.decode([DeviceCommand].self, from: data)) ?? []
    }
}
