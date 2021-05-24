//
//  NationalRailDataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 24/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class NationalRailDataSource : DataSource {
    // See https://wiki.openraildata.com/index.php/NRE_Darwin_Web_Service_(Public)
    // and https://lite.realtime.nationalrail.co.uk/OpenLDBWS/
    // As implemented by https://huxley.unop.uk/ because the raw national rail API is so bad
    let token = "KEY"

    var targetCrs: String?
    var sourceCrs: String?

    var dataItems = [DataItem]()
    var completion: DataSource.Callback?
    var task: URLSessionTask?

    func get<T>(_ what: String, onCompletion: @escaping (T?, Error?) -> Void) -> URLSessionTask where T : Decodable {
        let sep = what.contains("?") ? "&" : "?"
        let url = URL(string: "https://huxley.apphb.com/" + what + sep + "accessToken=\(token)")!
        return JSONRequest.makeRequest(url: url, onCompletion: onCompletion)
    }

    func fetchData(onCompletion: @escaping Callback) {
        task?.cancel()
        let route = Config().trainRoute
        sourceCrs = route.from
        targetCrs = route.to

        if let sourceCrs = sourceCrs, let targetCrs = targetCrs {
            completion = onCompletion
            task = get("delays/\(sourceCrs)/to/\(targetCrs)/10", onCompletion: gotDelays)
        } else {
            onCompletion(self, [], nil)
        }
    }

    struct Delays: Decodable {
        var delays: Bool
        var totalTrainsDelayed: Int
        var totalDelayMinutes: Int
        var delayedTrains: [Delay]

        struct Delay: Codable {
            var std: String
            var etd: String
            var isCancelled: Bool
        }
    }

    func gotDelays(data: Delays?, err: Error?) {
        task = nil
        dataItems = []
        guard let data = data else {
            completion?(self, dataItems, err)
            return
        }

        if data.delayedTrains.count == 0 {
            dataItems.append(DataItem("\(sourceCrs!) to \(targetCrs!) trains: Good Service"))
        }

        for delay in data.delayedTrains {
            // If we don't force a line break here, UILabel breaks the line after the "to"
            // which makes the resulting text look a bit unbalanced. But it only does this
            // when using the Amiga Forever font in non-editing mode (!?)
            var text = "\(delay.std) \(sourceCrs!) to \(targetCrs!):\u{2028}"
            if delay.isCancelled {
                text += "Cancelled"
            } else {
                let df = DateFormatter()
                df.dateFormat = "HH:mm"
                let std = df.date(from: delay.std)
                let etd = df.date(from: delay.etd)
                if (std != nil && etd != nil) {
                    let mins = Int(etd!.timeIntervalSince(std!) / 60)
                    text += "\(mins) mins late"
                } else {
                    text += "Delayed"
                }
            }
            dataItems.append(DataItem(text, flags: [DataItemFlag.warning]))
        }
        completion?(self, dataItems, err)
    }
}

