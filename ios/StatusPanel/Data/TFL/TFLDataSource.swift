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

// See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
class TFLDataSource: DataSource {

    struct LineStatus: Decodable {
        var id: String
        var name: String
        var lineStatuses: [LineStatusItem]

        struct LineStatusItem: Codable {
            var statusSeverity: Int
            var statusSeverityDescription: String
        }
    }

    // Key is the line id in the API, value is the human-readable name
    static let lines = [
        "bakerloo": "Bakerloo Line",
        "circle": "Circle Line",
        "central": "Central Line",
        "district": "District Line",
        "hammersmith-city": "Hammersmith & City Line",
        "jubilee": "Jubilee Line",
        "metropolitan": "Metropolitan Line",
        "northern": "Northern Line",
        "piccadilly": "Piccadilly Line",
        "victoria": "Victoria Line",
        "waterloo-city": "Waterloo & City Line",
    ]

    let configuration: Configuration

    var dataItems = [DataItem]()
    var completion: DataSource.Callback?
    var task: URLSessionTask?

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func fetchData(onCompletion: @escaping Callback) {
        task?.cancel()
        completion = onCompletion

        let activeLines = Config().activeTFLLines
        guard !activeLines.isEmpty else {
            onCompletion(self, [], nil)
            return
        }

        let url = URL(string: "https://api.tfl.gov.uk")?
            .appendingPathComponent("Line")
            .appendingPathComponent(activeLines.joined(separator: ","))
            .appendingPathComponent("Status")
            .settingQueryItems([
                URLQueryItem(name: "detail", value: "false"),
                URLQueryItem(name: "app_id", value: configuration.tflApiId),
                URLQueryItem(name: "app_key", value: configuration.tflApiKey),
            ])

        guard let safeUrl = url else {
            onCompletion(self, [], StatusPanelError.invalidUrl)
            return
        }

        task = JSONRequest.makeRequest(url: safeUrl, onCompletion: gotLineData)
    }

    func gotLineData(data: [LineStatus]?, err: Error?) {
        task = nil
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

            guard let name = Self.lines[line.id] else {
                completion?(self, [], StatusPanelError.invalidResponse("Unknown line identifier (\(line.id)"))
                return
            }

            dataItems.append(DataItem("\(name): \(desc)", flags: flags))
        }
        completion?(self, dataItems, err)
    }
}
