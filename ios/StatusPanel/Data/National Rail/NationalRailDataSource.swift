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
import SwiftUI
import UIKit

final class NationalRailDataSource : DataSource {
    // See https://wiki.openraildata.com/index.php/NRE_Darwin_Web_Service_(Public)
    // and https://lite.realtime.nationalrail.co.uk/OpenLDBWS/
    // As implemented by https://huxley.unop.uk/ because the raw national rail API is so bad

    struct TrainRoute: Codable {
        var from: String?
        var to: String?
        init(from: String?, to: String?) {
            self.from = from
            self.to = to
        }
    }

    struct Settings: DataSourceSettings {

        var routes: [TrainRoute]

        init(routes: [TrainRoute] = []) {
            self.routes = routes
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

    let name = "National Rail"
    let configurable = true

    let configuration: Configuration

    var targetCrs: String?
    var sourceCrs: String?

    var dataItems = [DataItem]()
    var completion: ((NationalRailDataSource, [DataItemBase], Error?) -> Void)?
    var task: URLSessionTask?

    var defaults: Settings { Settings() }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func data(settings: Settings,
              completion: @escaping (NationalRailDataSource, [DataItemBase], Error?) -> Void) {
        task?.cancel()

        guard let route = settings.routes.first,
              let sourceCrs = route.from,
              let targetCrs = route.to else {
                  completion(self, [], nil)
            return
        }

        self.sourceCrs = sourceCrs
        self.targetCrs = targetCrs

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
            completion(self, [], StatusPanelError.invalidUrl)
            return
        }

        self.completion = completion
        task = JSONRequest.makeRequest(url: safeUrl, onCompletion: gotDelays)
    }

    func gotDelays(data: Delays?, err: Error?) {
        task = nil
        dataItems = []
        guard let data = data else {
            completion?(self, dataItems, err)
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
        completion?(self, dataItems, err)
    }

    func summary(settings: Settings) -> String? {
        guard let route = settings.routes.first,
              let from = route.from,
              let to = route.to else {
            return "Not configured"
        }
        return "\(from) to \(to)"
    }

    func settingsViewController(settings: Settings, store: Store) -> UIViewController? {
        guard let viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "NationalRailEditor")
                as? NationalRailSettingsController else {
            return nil
        }
        viewController.store = store
        viewController.settings = settings
        return viewController
    }

    func settingsView(settings: Settings, store: Store) -> EmptyView {
        EmptyView()
    }
}
