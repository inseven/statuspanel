//
//  Config.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 20/11/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class Config {

    private let activeCalendarsKey = "activeCalendars"
    private let activeTFLLinesKey = "activeTFLLines"

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
            userDefaults.synchronize()
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
            userDefaults.synchronize()
        }
    }

    // The desired panel wake time, as a number of seconds since midnight (floating time)
    static func getWakeTime() -> TimeInterval {
        let result = UserDefaults.standard.value(forKey: "wakeTime")
        if result == nil {
            return (6 * 60 + 20) * 60
        } else {
            return result as! TimeInterval
        }
    }

    // The wake time relative to start of day GMT. If waketime is 6*60*60 then this returns the offset from midnight GMT to 0600 local time. It is always positive.
    static func getLocalWakeTime() -> TimeInterval {
        var result = getWakeTime() - TimeInterval(TimeZone.current.secondsFromGMT())
        if result < 0 {
            result += 24 * 60 * 60
        }
        return result
    }

    static func getDeviceAndKey() -> (String, String)? {
        let ud = UserDefaults.standard
        let deviceid = ud.string(forKey: "deviceid")
        let publickey = ud.string(forKey: "publickey")
        if deviceid == nil || publickey == nil {
            return nil
        } else {
            return (deviceid!, publickey!)
        }
    }
}
