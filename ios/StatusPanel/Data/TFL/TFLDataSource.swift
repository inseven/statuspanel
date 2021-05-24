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

class TFLDataSource : DataSource {
    // See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
    let app_id = "KEY"
    let app_key = "KEY"

    // Key is the line id in the API, value is the human-readable name
    static let lines = [
        "bakerloo": "Bakerloo",
        "cirle": "Circle",
        "central": "Central",
        "district": "District",
        // TODO what is Hammersmith & City's id?
        "jubilee": "Jubilee",
        "metropolitan": "Metropolitan",
        "northern": "Northern",
        "piccadilly": "Piccadilly",
        "victoria": "Victoria",
        // TODO what is Waterloo & City's id?
    ]

    var dataItems = [DataItem]()
    var completion: DataSource.Callback?
    var task: URLSessionTask?

    func get<T>(_ what: String, onCompletion: @escaping (T?, Error?) -> Void) -> URLSessionTask where T : Decodable {
        let sep = what.contains("?") ? "&" : "?"
        let url = URL(string: "https://api.tfl.gov.uk/" + what + sep + "app_id=\(app_id)&app_key=\(app_key)")!
        return JSONRequest.makeRequest(url: url, onCompletion: onCompletion)
    }

    func fetchData(onCompletion: @escaping Callback) {
        task?.cancel()
        completion = onCompletion
        let lines = Config().activeTFLLines.joined(separator: ",")
        if lines == "" {
            // Nothing to do
            onCompletion(self, [], nil)
        } else {
            task = get("Line/\(lines)/Status?detail=false", onCompletion: gotLineData)
        }
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
            dataItems.append(DataItem("\(line.name) line: \(desc)", flags: flags))
        }
        // print(dataItems)
        completion?(self, dataItems, err)
    }
}
