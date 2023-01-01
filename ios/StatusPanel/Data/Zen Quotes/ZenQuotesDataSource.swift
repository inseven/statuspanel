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

import SwiftUI

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

        var mode: Mode

    }

    struct Footer: View {

        var body: some View {
            Text("Inspirational quotes provided by ZenQuotes API.")
                .onTapGesture {
                    guard let url = URL(string: "https://zenquotes.io/") else {
                        return
                    }
                    UIApplication.shared.open(url, options: [:])
                }
        }
    }

    struct SettingsView: View {

        var store: Store
        @State var settings: Settings
        @State var error: Error? = nil

        var body: some View {
            Form {
                Section(footer: Footer()) {
                    Picker("Mode", selection: $settings.mode) {
                        Text(Settings.Mode.today.localizedName).tag(Settings.Mode.today)
                        Text(Settings.Mode.random.localizedName).tag(Settings.Mode.random)
                    }
                }
            }
            .alert(isPresented: $error.mappedToBool()) {
                Alert(error: error)
            }
            .onChange(of: settings) { newValue in
                do {
                    try store.save(settings: newValue)
                } catch {
                    self.error = error
                }
            }
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

    let id: DataSourceType = .zenQuotes
    let name = "ZenQuotes"
    let image = UIImage(systemName: "quote.bubble", withConfiguration: UIImage.SymbolConfiguration(scale: .large))!
    let configurable = true
    let defaults = Settings(mode: .today)

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
            completion([DataItem(icon: "💬", text: text, flags: [])], nil)
        }
    }

    func summary(settings: Settings) -> String? {
        return settings.mode.localizedName
    }

    func settingsViewController(store: Store, settings: Settings) -> UIViewController? {
        return UIHostingController(rootView: SettingsView(store: store, settings: settings))
    }

}
