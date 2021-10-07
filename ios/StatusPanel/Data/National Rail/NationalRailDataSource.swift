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

class NationalRailDataSource : DataSource {
    // See https://wiki.openraildata.com/index.php/NRE_Darwin_Web_Service_(Public)
    // and https://lite.realtime.nationalrail.co.uk/OpenLDBWS/
    // As implemented by https://huxley.unop.uk/ because the raw national rail API is so bad

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

    let configuration: Configuration

    var targetCrs: String?
    var sourceCrs: String?

    var dataItems = [DataItem]()
    var completion: DataSource.Callback?

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func fetchData(onCompletion: @escaping Callback) {
        let route = Config().trainRoute
        sourceCrs = route.from
        targetCrs = route.to

        guard let sourceCrs = sourceCrs,
              let targetCrs = targetCrs else {
            onCompletion([], nil)
            return
        }

        let url = URL(string: "https://huxley.apphb.com")?
            .appendingPathComponent("delays")
            .appendingPathComponent(sourceCrs)
            .appendingPathComponent("to")
            .appendingPathComponent(targetCrs)
            .appendingPathComponent("10")
            .settingQueryItems([
                URLQueryItem(name: "accessToken", value: configuration.nationalRailApiToken)
            ])

        guard let safeUrl = url else {
            onCompletion([], StatusPanelError.invalidUrl)
            return
        }

        completion = onCompletion
        JSONRequest.makeRequest(url: safeUrl, completion: gotDelays)
    }

    func gotDelays(data: Delays?, err: Error?) {
        dataItems = []
        guard let data = data else {
            completion?(dataItems, err)
            return
        }

        if data.delayedTrains.count == 0 {
            dataItems.append(DataItem(icon: "🚊", text: "\(sourceCrs!) to \(targetCrs!) trains: Good Service"))
        }

        for delay in data.delayedTrains {
            var text = "\(delay.std) \(sourceCrs!) to \(targetCrs!): "
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
            dataItems.append(DataItem(icon: "🚊", text: text, flags: [.warning]))
        }
        completion?(dataItems, err)
    }
}
