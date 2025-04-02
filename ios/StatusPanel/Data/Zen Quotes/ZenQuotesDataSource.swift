// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

import SwiftUI

import Diligence

final class ZenQuotesDataSource: DataSource {

    struct Settings: DataSourceSettings & Equatable {

        enum Mode: String, Codable {
            case today = "today"
            case random = "random"

            var localizedName: String {
                switch self {
                case .today:
                    return "Daily"
                case .random:
                    return "Random"
                }
            }

        }

        static let dataSourceType: DataSourceType = .zenQuotes

        var flags: DataItemFlags
        var mode: Mode

    }

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: ZenQuotesDataSource.image,
                                  title: ZenQuotesDataSource.name,
                                  summary: model.settings.mode.localizedName)
        }

    }

    struct SettingsView: View {

        @ObservedObject var model: Model

        var body: some View {
            Form {
                Section {
                    Picker("Mode", selection: $model.settings.mode) {
                        Text(Settings.Mode.today.localizedName).tag(Settings.Mode.today)
                        Text(Settings.Mode.random.localizedName).tag(Settings.Mode.random)
                    }
                }
                FlagsSection(flags: $model.settings.flags)
                Section {
                    Link("ZenQuotes", url: URL(string: "https://zenquotes.io/")!)
                    Link("Privacy Policy", url: URL(string: "https://docs.zenquotes.io/privacy-policy/")!)
                } header: {
                    Text("About")
                } footer: {
                    Text("Inspirational quotes provided by ZenQuotes API.")
                }
            }
            .presents($model.error)
        }

    }

    struct Quote: Codable {

        enum CodingKeys: String, CodingKey {
            case quote = "q"
            case author = "a"
        }

        var quote: String
        var author: String

    }

    static let id: DataSourceType = .zenQuotes
    static let name = "ZenQuotes"
    static let image = Image(systemName: "quote.bubble")
    
    let defaults = Settings(flags: [], mode: .today)

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {

        let url = URL(string: "https://zenquotes.io")?
            .settingQueryItems([
                URLQueryItem(name: "api", value: settings.mode.rawValue)
            ])

        guard let safeUrl = url else {
            completion([], StatusPanelError.invalidUrl)
            return
        }

        JSONRequest.makeRequest(url: safeUrl) { (data: [Quote]?, error: Error?) -> Void in

            guard let data = data else {
                completion([], error ?? StatusPanelError.internalInconsistency)
                return
            }

            guard let quote = data.first else {
                completion([], error ?? StatusPanelError.invalidResponse)
                return
            }

            let text = "\"\(quote.quote.trimmingCharacters(in: .whitespacesAndNewlines))\"—\(quote.author)"
            completion([DataItem(icon: "💬", text: text, flags: settings.flags)], nil)
        }
    }

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
