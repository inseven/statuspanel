//
//  Config.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 20/11/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class Config {

    struct TrainRoute {
        var from: String?
        var to: String?
        init(from: String?, to: String?) {
            self.from = from
            self.to = to
        }
    }

    private let activeCalendarsKey = "activeCalendars"
    private let activeTFLLinesKey = "activeTFLLines"
    private let updateTimeKey = "updateTime"
    private let trainRoutesKey = "trainRoutes"

    var activeCalendars: [String] {
        get {
            let userDefaults = UserDefaults.standard
            guard let identifiers = userDefaults.object(forKey: activeCalendarsKey) as? [String] else {
                return []
            }
            return identifiers
        }
        set {
            let userDefaults = UserDefaults.standard
            userDefaults.set(newValue, forKey: activeCalendarsKey)
        }
    }

    var activeTFLLines: [String] {
        get {
            let userDefaults = UserDefaults.standard
            guard let lines = userDefaults.object(forKey: activeTFLLinesKey) as? [String] else {
                return []
            }
            return lines
        }
        set {
            let userDefaults = UserDefaults.standard
            userDefaults.set(newValue, forKey: activeTFLLinesKey)
        }
    }

    // The desired panel wake time, as a number of seconds since midnight (floating time)
    var updateTime: TimeInterval {
        get {
            guard let result = UserDefaults.standard.value(forKey: updateTimeKey) as? TimeInterval else {
                return (6 * 60 + 20) * 60
            }
            return result
        }
        set {
            UserDefaults.standard.set(newValue, forKey: updateTimeKey)
        }
    }

    var trainRoutes: [TrainRoute] {
        get {
            guard let val = UserDefaults.standard.array(forKey: trainRoutesKey) as? [Dictionary<String,String>] else {
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
            UserDefaults.standard.set(val, forKey: trainRoutesKey)
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
            let result = UserDefaults.standard.string(forKey: "font")
            if result == nil || !availableFonts.contains(where: { $0.0 == result }) {
                // Unset, or a font we've since removed?
                return availableFonts[0].0
            } else {
                return result!
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "font")
        }
    }

    let availableFonts = [
        ("amiga4ever", "Amiga Forever"),
        ("font6x10_2", "Guicons Font"), // Genuinely have no idea what this is actually called
        ("advocut", "AdvoCut"),
        ("silkscreen", "Silkscreen"),
    ]

    enum DarkModeConfig: Int {
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

    #if targetEnvironment(simulator)
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
            return UserDefaults.standard.set(newValue, forKey: "showCalendarLocations")
        }
    }
}
