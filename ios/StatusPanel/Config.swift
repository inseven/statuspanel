// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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
import Network

class Config {

    private enum Key: RawRepresentable {

        case activeCalendars
        case activeTFLLines
        case darkMode
        case displaySingleColumn
        case dummyData
        case titleFont
        case bodyFont
        case lastBackgroundUpdate
        case maxLines
        case privacyMode
        case showCalendarLocations
        case showUrlsInCalendarLocations
        case trainRoutes
        case updateTime
        case showIcons
        case dataSources
        case settings(UUID)

        init?(rawValue: String) {
            switch rawValue {
            case "activeCalendars":
                self = .activeCalendars
            case "activeTFLLines":
                self = .activeTFLLines
            case "darkMode":
                self = .darkMode
            case "displaySingleColumn":
                self = .displaySingleColumn
            case "dummyData":
                self = .dummyData
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
            case "showCalendarLocations":
                self = .showCalendarLocations
            case "showUrlsInCalendarLocations":
                self = .showUrlsInCalendarLocations
            case "trainRoutes":
                self = .trainRoutes
            case "updateTime":
                self = .updateTime
            case "showIcons":
                self = .showIcons
            case "dataSources":
                self = .dataSources
            case _ where rawValue.starts(with: "Settings-"):
                guard let uuid = UUID(uuidString: String(rawValue.dropPrefix("Settings-"))) else {
                    return nil
                }
                self = .settings(uuid)
            default:
                return nil
            }
        }

        var rawValue: String {
            switch self {
            case .activeCalendars:
                return "activeCalendars"
            case .activeTFLLines:
                return "activeTFLLines"
            case .darkMode:
                return "darkMode"
            case .displaySingleColumn:
                return "displaySingleColumn"
            case .dummyData:
                return "dummyData"
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
            case .showCalendarLocations:
                return "showCalendarLocations"
            case .showUrlsInCalendarLocations:
                return "showUrlsInCalendarLocations"
            case .trainRoutes:
                return "trainRoutes"
            case .updateTime:
                return "updateTime"
            case .showIcons:
                return "showIcons"
            case .dataSources:
                return "dataSources"
            case .settings(let uuid):
                return "Settings-\(uuid.uuidString)"
            }
        }
    }

    struct TrainRoute {
        var from: String?
        var to: String?
        init(from: String?, to: String?) {
            self.from = from
            self.to = to
        }
    }

    let userDefaults = UserDefaults.standard

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

    private func set(_ value: Int, for key: Key) {
        self.userDefaults.set(value, forKey: key.rawValue)
    }

    private func set(_ value: Bool, for key: Key) {
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
        set {
            self.set(newValue, for: .activeCalendars)
        }
    }

    var activeTFLLines: [String] {
        get {
            self.object(for: .activeTFLLines) as? [String] ?? []
        }
        set {
            self.set(newValue, for: .activeTFLLines)
        }
    }

    // The desired panel wake time, as a number of seconds since midnight (floating time)
    var updateTime: TimeInterval {
        get {
            self.value(for: .updateTime) as? TimeInterval ?? (6 * 60 + 20) * 60
        }
        set {
            self.set(newValue, for: .updateTime)
        }
    }

    var showIcons: Bool {
        get {
            self.bool(for: .showIcons, default: true)
        }
        set {
            self.set(newValue, for: .showIcons)
        }
    }

    var trainRoutes: [TrainRoute] {
        get {
            guard let val = self.array(for: .trainRoutes) as? [Dictionary<String,String>] else {
                return []
            }
            var result: [TrainRoute] = []
            for dict in val {
                result.append(TrainRoute(from: dict["from"], to: dict["to"]))
            }
            return result
        }
        set {
            var val: [Dictionary<String,String>] = []
            for route in newValue {
                var dict = Dictionary<String,String>()
                if (route.from != nil) {
                    dict["from"] = route.from!
                }
                if (route.to != nil) {
                    dict["to"] = route.to!
                }
                val.append(dict)
            }
            self.set(val, for: .trainRoutes)
        }
    }

    var trainRoute: TrainRoute {
        get {
            let routes = trainRoutes
            if routes.count > 0 {
                return routes[0]
            } else {
                return TrainRoute(from: nil, to: nil)
            }
        }
        set {
            trainRoutes = [newValue]
        }
    }

    static func getWakeTime() -> TimeInterval {
        return Config().updateTime
    }


    // The wake time relative to start of day GMT. If waketime is 6*60*60 then this returns the offset from midnight GMT to 0600 local time. It is always positive.
    static func getLocalWakeTime() -> TimeInterval {
        var result = getWakeTime() - TimeInterval(TimeZone.current.secondsFromGMT())
        if result < 0 {
            result += 24 * 60 * 60
        }
        return result
    }

    // Old way of storing a single device and key
    static private func getDeviceAndKey() -> (String, String)? {
        let ud = UserDefaults.standard
        let deviceid = ud.string(forKey: "deviceid")
        let publickey = ud.string(forKey: "publickey")
        if deviceid == nil || publickey == nil {
            return nil
        } else {
            return (deviceid!, publickey!)
        }
    }

    var devices: [(String, String)] {
        get {
            let ud = UserDefaults.standard
            if let oldStyle = Config.getDeviceAndKey() {
                // Migrate
                let devices = [oldStyle]
                ud.removeObject(forKey: "deviceid")
                ud.removeObject(forKey: "publickey")
                self.devices = devices
            }
            guard let deviceObjs = ud.array(forKey: "devices") as? [Dictionary<String, String>] else {
                return []
            }
            var result: [(String, String)] = []
            for obj in deviceObjs {
                guard let deviceid = obj["deviceid"], let publickey = obj["publickey"] else {
                    continue
                }
                result.append((deviceid, publickey))
            }
            return result
        }
        set {
            var objs: [Dictionary<String, String>] = []
            for (deviceid, publickey) in newValue {
                objs.append(["publickey": publickey, "deviceid": deviceid])
            }
            self.userDefaults.set(objs, forKey: "devices")
        }
    }

    var displayTwoColumns: Bool {
        get {
            !self.bool(for: .displaySingleColumn)
        }
        set {
            self.set(!newValue, for: .displaySingleColumn)
        }
    }

    var titleFont: String {
        get {
            self.string(for: .titleFont) ?? availableFonts[0].configName
        }
        set {
            self.set(newValue, for: .titleFont)
        }
    }

    var bodyFont: String {
        get {
            self.string(for: .bodyFont) ?? availableFonts[0].configName
        }
        set {
            self.set(newValue, for: .bodyFont)
        }
    }

    typealias Font = Fonts.Font
    let availableFonts = Fonts.availableFonts

    func getFont(named: String) -> Font {
        for font in availableFonts {
            if font.configName == named {
                return font
            }
        }
        return availableFonts[0]
    }

    enum DarkModeConfig: Int, CaseIterable {
        case off = 0
        case on = 1
        case system = 2
    }

    var darkMode: DarkModeConfig {
        get {
            DarkModeConfig.init(rawValue: self.integer(for: .darkMode))!
        }
        set {
            self.set(newValue.rawValue, for: .darkMode)
        }
    }

    var showDummyData: Bool {
        get {
            self.bool(for: .dummyData)
        }
        set {
            self.set(newValue, for: .dummyData)
        }
    }

    var showCalendarLocations: Bool {
        get {
            self.bool(for: .showCalendarLocations)
        }
        set {
            self.set(newValue, for: .showCalendarLocations)
        }
    }

    var showUrlsInCalendarLocations: Bool {
        get {
            self.bool(for: .showUrlsInCalendarLocations)
        }
        set {
            self.set(newValue, for: .showUrlsInCalendarLocations)
        }
    }

    // 0 means unlimited
    var maxLines: Int {
        get {
            self.integer(for: .maxLines)
        }
        set {
            self.set(newValue, for: .maxLines)
        }
    }

    enum PrivacyMode: Int, CaseIterable {
        case redactLines = 0
        case redactWords = 1
        case customImage = 2
    }

    var privacyMode: PrivacyMode {
        get {
            PrivacyMode.init(rawValue: self.integer(for: .privacyMode))!
        }
        set {
            self.set(newValue.rawValue, for: .privacyMode)
        }
    }

    private static func getLastUploadHashKey(for deviceid: String) -> String {
        return "lastUploadedHash_\(deviceid)"
    }

    func setLastUploadHash(for deviceid: String, to hash:String?) {
        let key = Config.getLastUploadHashKey(for: deviceid)
        if let hash = hash {
            self.userDefaults.set(hash, forKey: key)
        } else {
            self.userDefaults.removeObject(forKey: key)
        }
    }

    func getLastUploadHash(for deviceid: String) -> String? {
        return self.userDefaults.string(forKey: Config.getLastUploadHashKey(for: deviceid))
    }

    var lastBackgroundUpdate: Date? {
        get {
            self.object(for: .lastBackgroundUpdate) as? Date
        }
        set {
            self.set(newValue, for: .lastBackgroundUpdate)
        }
    }

    func dataSources() throws -> [DataSourceInstance.Details]? {
        return try self.decodeObject(for: .dataSources)
    }

    func set(dataSources: [DataSourceInstance.Details]) throws {
        try self.set(codable: dataSources, for: .dataSources)
    }

    func settings<T: DataSourceSettings>(for uuid: UUID) throws -> T? {
        guard let data = object(for: .settings(uuid)) as? Data else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data as Data)
    }

    func save<T: DataSourceSettings>(settings: T, uuid: UUID) throws {
        let data = try JSONEncoder().encode(settings)
        set(data, for: .settings(uuid))
    }

}
