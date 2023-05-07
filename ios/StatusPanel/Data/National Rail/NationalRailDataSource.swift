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
import SwiftUI

final class NationalRailDataSource : DataSource {
    // See https://wiki.openraildata.com/index.php/NRE_Darwin_Web_Service_(Public)
    // and https://lite.realtime.nationalrail.co.uk/OpenLDBWS/
    // As implemented by https://huxley.unop.uk/ because the raw national rail API is so bad

    struct Settings: DataSourceSettings {

        var from: String?
        var to: String?

        var summary: String {
            if let from,
               let to {
                return "\(from) to \(to)"
            } else {
                return "Not configured"
            }
        }

    }

    struct NationalRailSettingsView: UIViewControllerRepresentable {

        let model: Model

        func makeUIViewController(context: Context) -> some UIViewController {
            return NationalRailSettingsController(model: model)
        }

        func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        }

    }

    struct SettingsView: View {

        let model: Model

        var body: some View {
            NationalRailSettingsView(model: model)
                .edgesIgnoringSafeArea(.all)
        }

    }

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: NationalRailDataSource.image,
                                  title: NationalRailDataSource.name,
                                  summary: model.settings.summary)
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

    static let id: DataSourceType = .nationalRail
    static let name = "National Rail"
    static let image = Image(systemName: "tram.fill")

    let configuration: Configuration

    var defaults: Settings {
        return Settings()
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {

        guard let sourceCrs = settings.from,
              let targetCrs = settings.to else {
                  completion([], nil)
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
            completion([], StatusPanelError.invalidUrl)
            return
        }

        let gotDelays: (Delays?, Error?) -> Void = { data, error in
            var dataItems = [DataItem]()
            guard let data = data else {
                completion(dataItems, error)
                return
            }

            if data.delayedTrains.count == 0 {
                dataItems.append(DataItem(icon: "🚊", text: "\(sourceCrs) to \(targetCrs) trains: Good Service"))
            }

            for delay in data.delayedTrains {
                var text = "\(delay.std) \(sourceCrs) to \(targetCrs): "
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
            completion(dataItems, error)
        }

        JSONRequest.makeRequest(url: safeUrl, completion: gotDelays)
    }

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
