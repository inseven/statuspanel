// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import UIKit

class Config: ObservableObject {

    enum DarkMode: Int, CaseIterable, Codable {
        case off = 0
        case on = 1
        case system = 2
    }

    enum PrivacyMode: Int, CaseIterable, Codable {
        case redactLines = 0
        case redactWords = 1
        case customImage = 2
    }

    private enum Key: RawRepresentable {

        case activeCalendars
        case darkMode
        case displaySingleColumn
        case titleFont
        case bodyFont
        case lastBackgroundUpdate
        case maxLines
        case privacyMode
        case updateTime
        case showIcons
        case dataSources
        case settings(UUID)
        case deviceSettings(String)
        case showDeveloperTools

        static let settingsPrefix = "Settings-"
        static let deviceSettingsPrefix = "DeviceSettings-"

        init?(rawValue: String) {
            switch rawValue {
            case "activeCalendars":
                self = .activeCalendars
            case "darkMode":
                self = .darkMode
            case "displaySingleColumn":
                self = .displaySingleColumn
            case "titleFont":
                self = .titleFont
            case "font":
                self = .bodyFont
            case "lastBackgroundUpdate":
                self = .lastBackgroundUpdate
            case "maxLines":
                self = .maxLines
            case "privacyMode":
                self = .privacyMode
            case "updateTime":
                self = .updateTime
            case "showIcons":
                self = .showIcons
            case "dataSources":
                self = .dataSources
            case _ where rawValue.starts(with: Self.settingsPrefix):
                guard let uuid = UUID(uuidString: String(rawValue.dropFirst(Self.settingsPrefix.count))) else {
                    return nil
                }
                self = .settings(uuid)
            case _ where rawValue.starts(with: Self.deviceSettingsPrefix):
                let deviceId = String(rawValue.dropFirst(Self.deviceSettingsPrefix.count))
                self = .deviceSettings(deviceId)
            default:
                return nil
            }
        }

        var rawValue: String {
            switch self {
            case .activeCalendars:
                return "activeCalendars"
            case .darkMode:
                return "darkMode"
            case .displaySingleColumn:
                return "displaySingleColumn"
            case .titleFont:
                return "titleFont"
            case .bodyFont:
                return "font"
            case .lastBackgroundUpdate:
                return "lastBackgroundUpdate"
            case .maxLines:
                return "maxLines"
            case .privacyMode:
                return "privacyMode"
            case .updateTime:
                return "updateTime"
            case .showIcons:
                return "showIcons"
            case .dataSources:
                return "dataSources"
            case .settings(let uuid):
                return "\(Self.settingsPrefix)\(uuid.uuidString)"
            case .deviceSettings(let deviceId):
                return "\(Self.deviceSettingsPrefix)\(deviceId)"
            case .showDeveloperTools:
                return "showDeveloperTools"
            }
        }
    }

    let userDefaults = UserDefaults.standard

    @MainActor init() {
        devices = Self.loadDevices()
        lastBackgroundUpdate = object(for: .lastBackgroundUpdate) as? Date
        showDeveloperTools = bool(for: .showDeveloperTools)

        // Migrate the valid device keys.
        // This addresses a legacy bug where device settings were incorrectly prefixed with 'Settings-' not
        // 'DeviceSettings-'.
        let legacyDeviceKeys = devices.map { "Settings-\($0.id)" }
        for legacyKey in legacyDeviceKeys {
            guard let data = userDefaults.object(forKey: legacyKey) as? Data else {
                continue
            }
            let newKey = "Device" + legacyKey
            print("Migrating legacy device key from '\(legacyKey)' to '\(newKey)'...")
            userDefaults.set(data, forKey: newKey)
            userDefaults.removeObject(forKey: legacyKey)
        }

        // Determine the valid device and data source settings identifiers.
        let deviceSettingsKeys = devices.map { Key.deviceSettings($0.id).rawValue }
        let dataSourceSettingsKeys = devices
            .map { (try? settings(forDevice: $0.id).dataSources.map { Key.settings($0.id).rawValue }) ?? [] }
            .reduce([], +)
        let settingsKeys = Set(deviceSettingsKeys + dataSourceSettingsKeys)

        // Clean up orphaned settings.
        for key in userDefaults.dictionaryRepresentation().keys {
            guard
                key.starts(with: Key.settingsPrefix) || key.starts(with: Key.deviceSettingsPrefix),
                  !settingsKeys.contains(key)
            else {
                continue
            }
            print("Cleaning up '\(key)'...")
            userDefaults.removeObject(forKey: key)
        }
    }

    private func object(for key: Key) -> Any? {
        return self.userDefaults.object(forKey: key.rawValue)
    }

    private func value(for key: Key) -> Any? {
        return self.userDefaults.value(forKey: key.rawValue)
    }

    private func array(for key: Key) -> [Any]? {
        return self.userDefaults.array(forKey: key.rawValue)
    }

    private func string(for key: Key) -> String? {
        return self.userDefaults.string(forKey: key.rawValue)
    }

    private func integer(for key: Key) -> Int {
        return self.userDefaults.integer(forKey: key.rawValue)
    }

    private func bool(for key: Key, default defaultValue: Bool = false) -> Bool {
        guard let value = self.userDefaults.object(forKey: key.rawValue) as? Bool else {
            return defaultValue
        }
        return value
    }

    private func decodeObject<T: Codable>(for key: Key) throws -> T? {
        guard let data = self.userDefaults.object(forKey: key.rawValue) as? Data else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func set(_ value: Any?, for key: Key) {
        self.userDefaults.set(value, forKey: key.rawValue)
    }

    private func set<T: Codable>(codable: T, for key: Key) throws {
        let data = try JSONEncoder().encode(codable)
        self.userDefaults.set(data, forKey: key.rawValue)
    }

    var activeCalendars: [String] {
        get {
            self.object(for: .activeCalendars) as? [String] ?? []
        }
    }

    // Old way of storing a single device and key
    @MainActor static private func getDeviceAndKey() -> Device? {
        let userDefaults = UserDefaults.standard
        guard let deviceid = userDefaults.string(forKey: "deviceid"),
              let publickey = userDefaults.string(forKey: "publickey")
        else {
            return nil
        }
        return Device(kind: .einkV1, id: deviceid, publicKey: publickey)
    }

    @MainActor static private func loadDevices() -> Set<Device> {
        let userDefaults = UserDefaults.standard
        if let oldStyle = getDeviceAndKey() {
            // Migrate
            let devices = [oldStyle]
            userDefaults.removeObject(forKey: "deviceid")
            userDefaults.removeObject(forKey: "publickey")
            return Set(devices)
        }
        guard let deviceObjs = userDefaults.array(forKey: "devices") as? [Dictionary<String, String>] else {
            return []
        }
        var result: [Device] = []
        for obj in deviceObjs {
            guard let deviceid = obj["deviceid"],
                  let publickey = obj["publickey"],
                  let kind = Device.Kind(rawValue: obj["kind"] ?? Device.Kind.einkV1.rawValue)
            else {
                continue
            }
            result.append(Device(kind: kind, id: deviceid, publicKey: publickey))
        }
        return Set(result)
    }

    @MainActor @Published var devices: Set<Device> {
        didSet {
            var objs: [Dictionary<String, String>] = []
            for device in devices {
                objs.append(["publickey": device.publicKey, "deviceid": device.id, "kind": device.kind.rawValue])
            }
            self.userDefaults.set(objs, forKey: "devices")
        }
    }

    @MainActor @Published var showDeveloperTools: Bool = false {
        didSet {
            set(showDeveloperTools, for: .showDeveloperTools)
        }
    }

    @MainActor func removeDevice(_ device: Device) {
        self.devices.remove(device)
    }

    private static func getLastUploadHashKey(for deviceid: String) -> String {
        return "lastUploadedHash_\(deviceid)"
    }

    @MainActor func setLastUploadHash(for deviceid: String, to hash:String?) {
        dispatchPrecondition(condition: .onQueue(.main))
        let key = Config.getLastUploadHashKey(for: deviceid)
        if let hash = hash {
            self.userDefaults.set(hash, forKey: key)
        } else {
            self.userDefaults.removeObject(forKey: key)
        }
    }

    @MainActor func getLastUploadHash(for deviceid: String) -> String? {
        dispatchPrecondition(condition: .onQueue(.main  ))
        return self.userDefaults.string(forKey: Config.getLastUploadHashKey(for: deviceid))
    }

    @MainActor func clearUploadHashes() {
        for device in devices {
            setLastUploadHash(for: device.id, to: nil)
        }
    }

    @Published var lastBackgroundUpdate: Date? {
        didSet {
            self.set(lastBackgroundUpdate, for: .lastBackgroundUpdate)
        }
    }

    func settings<T: DataSourceSettings>(for instanceId: UUID) throws -> T? {
        guard let data = object(for: .settings(instanceId)) as? Data else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data as Data)
    }

    func save<T: DataSourceSettings>(settings: T, instanceId: UUID) throws {
        let data = try JSONEncoder().encode(settings)
        set(data, for: .settings(instanceId))
    }

    func save(settings: AnyDataSourceSettings, instanceId: UUID) throws {
        let data = try JSONEncoder().encode(settings)
        set(data, for: .settings(instanceId))
    }

    func settings(forDevice deviceId: String) throws -> DeviceSettings {
        dispatchPrecondition(condition: .onQueue(.main))
        let key = Key.deviceSettings(deviceId)
        guard let data = object(for: .deviceSettings(deviceId)) as? Data else {
            var settings = DeviceSettings(deviceId: deviceId)
            settings.displayTwoColumns = !bool(for: .displaySingleColumn)
            settings.showIcons = bool(for: .showIcons, default: true)
            settings.darkMode = DarkMode.init(rawValue: integer(for: .darkMode))!
            settings.maxLines = integer(for: .maxLines)
            settings.privacyMode = PrivacyMode.init(rawValue: integer(for: .privacyMode))!
            settings.updateTime = Date(timeIntervalSinceReferenceDate: self.value(for: .updateTime) as? TimeInterval ?? DeviceSettings.defaultUpdateTime)
            settings.titleFont = string(for: .titleFont) ?? Fonts.FontName.chiKareGo2
            settings.bodyFont = string(for: .bodyFont) ?? Fonts.FontName.unifont16
            if let dataSources = try self.decodeObject(for: .dataSources) as [DataSourceInstance.Details]? {
                settings.dataSources = dataSources
            }
            return settings
        }
        return try JSONDecoder().decode(DeviceSettings.self, from: data as Data)
    }

    func save(settings: DeviceSettings, deviceId: String) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        let data = try JSONEncoder().encode(settings)
        set(data, for: .deviceSettings(deviceId))
    }

}
