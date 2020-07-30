//
//  Config.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 20/11/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class Config {

    private enum Key: String {
        case activeCalendars = "activeCalendars"
        case activeTFLLines = "activeTFLLines"
        case updateTime = "updateTime"
        case trainRoutes = "trainRoutes"
        case lastBackgroundUpdate = "lastBackgroundUpdate"
        case privacyMode = "privacyMode"
    }

    struct TrainRoute {
        var from: String?
        var to: String?
        init(from: String?, to: String?) {
            self.from = from
            self.to = to
        }
    }

    var activeCalendars: [String] {
        get {
            let userDefaults = UserDefaults.standard
            guard let identifiers = userDefaults.object(forKey: Key.activeCalendars.rawValue) as? [String] else {
                return []
            }
            return identifiers
        }
        set {
            let userDefaults = UserDefaults.standard
            userDefaults.set(newValue, forKey: Key.activeCalendars.rawValue)
        }
    }

    var activeTFLLines: [String] {
        get {
            let userDefaults = UserDefaults.standard
            guard let lines = userDefaults.object(forKey: Key.activeTFLLines.rawValue) as? [String] else {
                return []
            }
            return lines
        }
        set {
            let userDefaults = UserDefaults.standard
            userDefaults.set(newValue, forKey: Key.activeTFLLines.rawValue)
        }
    }

    // The desired panel wake time, as a number of seconds since midnight (floating time)
    var updateTime: TimeInterval {
        get {
            guard let result = UserDefaults.standard.value(forKey: Key.updateTime.rawValue) as? TimeInterval else {
                return (6 * 60 + 20) * 60
            }
            return result
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.updateTime.rawValue)
        }
    }

    var trainRoutes: [TrainRoute] {
        get {
            guard let val = UserDefaults.standard.array(forKey: Key.trainRoutes.rawValue) as? [Dictionary<String,String>] else {
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
            UserDefaults.standard.set(val, forKey: Key.trainRoutes.rawValue)
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
            UserDefaults.standard.setValue(objs, forKey: "devices")
        }
    }

    var displayTwoColumns: Bool {
        get {
            return !UserDefaults.standard.bool(forKey:"displaySingleColumn")
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: "displaySingleColumn")
        }
    }

    var font: String {
        get {
            if let result = UserDefaults.standard.string(forKey: "font") {
                return result
            } else {
                return availableFonts[0].configName
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "font")
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
        case off = 0, on = 1, system = 2
    }

    var darkMode: DarkModeConfig {
        get {
            return DarkModeConfig.init(rawValue: UserDefaults.standard.integer(forKey: "darkMode"))!
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: "darkMode")
        }
    }

    #if DEBUG
        var showDummyData: Bool {
            get {
                return UserDefaults.standard.bool(forKey: "dummyData")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "dummyData")
            }
        }
    #endif

    var showCalendarLocations: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showCalendarLocations")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showCalendarLocations")
        }
    }

    var showUrlsInCalendarLocations: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showUrlsInCalendarLocations")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showUrlsInCalendarLocations")
        }
    }

    // 0 means unlimited
    var maxLines: Int {
        get {
            return UserDefaults.standard.integer(forKey: "maxLines")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxLines")
        }
    }

    enum PrivacyMode: Int, CaseIterable {
        case redactLines = 0, redactWords = 1, customImage = 2
    }

    var privacyMode: PrivacyMode {
        get {
            return PrivacyMode.init(rawValue: UserDefaults.standard.integer(forKey: Key.privacyMode.rawValue))!
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: Key.privacyMode.rawValue)
        }
    }

    private static func getLastUploadHashKey(for deviceid: String) -> String {
        return "lastUploadedHash_\(deviceid)"
    }

    static func setLastUploadHash(for deviceid: String, to hash:String?) {
        let key = getLastUploadHashKey(for: deviceid)
        if let hash = hash {
            UserDefaults.standard.setValue(hash, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func getLastUploadHash(for deviceid: String) -> String? {
        return UserDefaults.standard.string(forKey: getLastUploadHashKey(for: deviceid))
    }

    var lastBackgroundUpdate: Date? {
        get {
            return UserDefaults.standard.object(forKey: Key.lastBackgroundUpdate.rawValue) as? Date
        }
        set {
            let userDefaults = UserDefaults.standard
            userDefaults.set(newValue, forKey: Key.lastBackgroundUpdate.rawValue)
            userDefaults.synchronize()
        }
    }
}
