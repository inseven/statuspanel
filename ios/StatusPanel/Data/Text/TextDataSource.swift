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

import Diligence

final class TextDataSource: DataSource {

    struct Settings: DataSourceSettings & Equatable {

        static let dataSourceType: DataSourceType = .text

        var flags: DataItemFlags
        var text: String
    }

    struct SettingsView: View {

        @ObservedObject var model: Model

        var body: some View {
            Form {
                Section {
                    TextField("Text", text: $model.settings.text)
                }
                FlagsSection(flags: $model.settings.flags)
            }
            .presents($model.error)
        }

    }

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: TextDataSource.image,
                                  title: TextDataSource.name,
                                  summary: model.settings.text)
        }

    }

    static let id: DataSourceType = .text
    static let name = "Text"
    static let image = Image(systemName: "textformat")
    
    let defaults = Settings(flags: [], text: "")

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {
        completion([DataItem(text: settings.text, flags: settings.flags)], nil)
    }

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
