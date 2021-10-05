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

import SwiftUI

final class TextDataSource: DataSource {

    struct Settings: DataSourceSettings & Equatable {
        var flags: DataItemFlags
        var text: String
    }

    struct SettingsView: View {

        var store: Store
        @State var settings: Settings

        var body: some View {
            Form {
                Section {
                    TextField("Text", text: $settings.text)
                }
                FlagsSection(flags: $settings.flags)
            }
            .onChange(of: settings) { newValue in
                try! store.save(settings: settings)
            }
        }

    }

    let id: DataSourceType = .text
    let name = "Text"
    let configurable = true
    let defaults = Settings(flags: [], text: "")

    func data(settings: Settings, completion: @escaping Callback) {
        completion(self, [DataItem(text: settings.text, flags: settings.flags)], nil)
    }

    func summary(settings: Settings) -> String? {
        settings.text
    }

    func settingsViewController(settings: Settings, store: Store) -> UIViewController? {
        nil
    }

    // TODO: Re-order the store and the settingss.
    func settingsView(settings: Settings, store: Store) -> SettingsView {
        SettingsView(store: store, settings: settings)
    }

}
