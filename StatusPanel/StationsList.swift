//
//  StationsList.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 30/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class StationsList {
    private static var stations: [Station]?
    private static var codeMap: [String: Station]?

    private static func checkLoaded() {
        if stations == nil {
            let stationData = NSDataAsset(name: "NationalRailStations")!.data
            stations = try! JSONDecoder().decode([Station].self, from: stationData)
            codeMap = [:]
            for station in stations! {
                codeMap![station.code] = station
            }
        }
    }

    static func get() -> [Station] {
        checkLoaded()
        return stations!
    }

    static func lookup(code: String?) -> Station? {
        guard let code = code else {
            return nil
        }
        checkLoaded()
        return codeMap![code]
    }
}
