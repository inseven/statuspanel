//
//  TFLDataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class TFLDataSource : DataSource {
    // See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
    let app_id = "KEY"
    let app_key = "KEY"

    var linesOfInterest = ["northern" /*, "central"*/]
    var dataItems = [DataItem]()
    var completion: DataSource.Callback?


    func get<T>(_ what: String, onCompletion: @escaping (T?, Error?) -> Void) where T : Decodable {
        let sep = what.contains("?") ? "&" : "?"
        let url = URL(string: "https://api.tfl.gov.uk/" + what + sep + "app_id=\(app_id)&app_key=\(app_key)")!
        JSONRequest.makeRequest(url: url, onCompletion: onCompletion)
    }

    func fetchData(onCompletion: @escaping Callback) {
        completion = onCompletion
        let lines = linesOfInterest.joined(separator: ",")
        get("Line/\(lines)/Status?detail=false", onCompletion: gotLineData)
    }

    struct LineStatus: Decodable {
        var name: String
        var lineStatuses: [LineStatusItem]

        struct LineStatusItem: Codable {
            var statusSeverity: Int
            var statusSeverityDescription: String
        }
    }

    func gotLineData(data: [LineStatus]?, err: Error?) {
        dataItems = []
        for line in data ?? [] {
            if line.lineStatuses.count < 1 {
                continue
            }
            let desc = line.lineStatuses[0].statusSeverityDescription
            let sev = line.lineStatuses[0].statusSeverity
            var flags: Set<DataItemFlag> = []
            if sev < 10 {
                flags.insert(.warning)
            }
            dataItems.append(DataItem("\(line.name) line: \(desc)", flags: flags))
        }
        // print(dataItems)
        completion?(self, dataItems, err)
    }
}
