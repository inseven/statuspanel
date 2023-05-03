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
import UIKit
import SwiftUI

import Diligence

// See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
final class TFLDataSource: DataSource {

    struct Line: Identifiable, Comparable {

        static func < (lhs: TFLDataSource.Line, rhs: TFLDataSource.Line) -> Bool {
            return lhs.title < rhs.title
        }

        var id: String
        var title: String
        var color: Color

    }

    struct Settings: DataSourceSettings & Equatable {

        var lines: Set<String>

        init(lines: Set<String>) {
            self.lines = lines
        }

        init() {
            self.init(lines: [])
        }

    }

    struct SettingsView: View {

        var store: DataSourceSettingsStore<TFLDataSource.Settings>
        @State var settings: TFLDataSource.Settings

        private var lines: [TFLDataSource.Line]
        @State var error: Error? = nil

        init(store: DataSourceSettingsStore<TFLDataSource.Settings>, settings: TFLDataSource.Settings) {
            self.store = store
            _settings = State(wrappedValue: settings)
            self.lines = TFLDataSource.lines.sorted()
        }

        var body: some View {
            Form {
                ForEach(lines) { line in
                    Toggle(line.title, isOn: $settings.lines.binding(for: line.id))
                        .toggleStyle(ColoredCheckbox(color: line.color))
                }
                Section {
                    Link("TfL Transport Data Service", url: URL(string: "https://api.tfl.gov.uk")!)
                    Link("Privacy Policy", url: URL(string: "https://tfl.gov.uk/corporate/privacy-and-cookies/")!)
                } header: {
                    Text("About")
                } footer: {
                    Text("Powered by TfL Open Data. Contains OS data © Crown copyright and database rights 2016' and Geomni UK Map data © and database rights [2019].")
                }
            }
            .presents($error)
            .onChange(of: settings) { newValue in
                do {
                    try store.save(settings: newValue)
                } catch {
                    self.error = error
                }
            }

        }

    }

    struct LineStatus: Decodable {
        var id: String
        var name: String
        var lineStatuses: [LineStatusItem]

        struct LineStatusItem: Codable {
            var statusSeverity: Int
            var statusSeverityDescription: String
        }
    }

    static var lines = [
        Line(id: "bakerloo", title: "Bakerloo Line", color: Color(hex: 0xb36305)),
        Line(id: "central", title: "Central Line", color: Color(hex: 0xe32017)),
        Line(id: "circle", title: "Circle Line", color: Color(hex: 0xffd300)),
        Line(id: "district", title: "District Line", color: Color(hex: 0x00782a)),
        Line(id: "elizabeth", title: "Elizabeth Line", color: Color(hex: 0x6950a1)),
        Line(id: "hammersmith-city", title: "Hammersmith & City Line", color: Color(hex: 0xf3a9bb)),
        Line(id: "jubilee", title: "Jubilee Line", color: Color(hex: 0xa0a5a9)),
        Line(id: "metropolitan", title: "Metropolitan Line", color: Color(hex: 0x9b0056)),
        Line(id: "northern", title: "Northern Line", color: Color(hex: 0x000000)),
        Line(id: "piccadilly", title: "Piccadilly Line", color: Color(hex: 0x003688)),
        Line(id: "victoria", title: "Victoria Line", color: Color(hex: 0x0098d4)),
        Line(id: "waterloo-city", title: "Waterloo & City Line", color: Color(hex: 0x95cdba)),
    ]

    private var linesById: [String: Line] = [:]

    let id: DataSourceType = .transportForLondon
    let name = "London Underground"
    let image = UIImage(systemName: "tram", withConfiguration: UIImage.SymbolConfiguration(scale: .large))!
    let configurable = true

    let configuration: Configuration

    var defaults: Settings {
        return Settings()
    }

    init(configuration: Configuration) {
        self.configuration = configuration
        linesById = Self.lines.reduce(into: [String: Line]()) {  $0[$1.id] = $1 }
    }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {

        // Remove any unknown lines.
        let lines = settings.lines.filter { self.linesById[$0] != nil }

        guard !lines.isEmpty else {
            completion([], nil)
            return
        }

        let url = URL(string: "https://api.tfl.gov.uk")?
            .appendingPathComponent("Line")
            .appendingPathComponent(lines.joined(separator: ","))
            .appendingPathComponent("Status")
            .settingQueryItems([
                URLQueryItem(name: "detail", value: "false"),
                URLQueryItem(name: "app_id", value: configuration.tflApiId),
                URLQueryItem(name: "app_key", value: configuration.tflApiKey),
            ])

        guard let safeUrl = url else {
            completion([], StatusPanelError.invalidUrl)
            return
        }

        let gotLineData: ([LineStatus]?, Error?) -> Void = { data, error in
            var dataItems = [DataItem]()
            for line in data ?? [] {
                if line.lineStatuses.count < 1 {
                    continue
                }
                let desc = line.lineStatuses[0].statusSeverityDescription
                let sev = line.lineStatuses[0].statusSeverity
                var flags: DataItemFlags = []
                if sev < 10 {
                    flags.insert(.warning)
                }

                guard let name = self.linesById[line.id]?.title else {
                    completion([], StatusPanelError.invalidResponse)
                    return
                }

                guard let accentColor = self.linesById[line.id]?.color.cgColor else {
                    completion([], StatusPanelError.invalidResponse)
                    return
                }

                dataItems.append(DataItem(icon: "🚇",
                                          text: "\(name): \(desc)",
                                          flags: flags,
                                          accentColor: UIColor(cgColor: accentColor)))
            }
            completion(dataItems, error)
        }

        JSONRequest.makeRequest(url: safeUrl, completion: gotLineData)
    }

    func summary(settings: Settings) -> String? {
        let activeLines = settings.lines.compactMap { linesById[$0] }.sorted()
        guard !activeLines.isEmpty else {
            return "None"
        }
        return activeLines.map { $0.title }.joined(separator: ", ")
    }

    func settingsView(store: Store, settings: Settings) -> SettingsView {
        return SettingsView(store: store, settings: settings)
    }

}
