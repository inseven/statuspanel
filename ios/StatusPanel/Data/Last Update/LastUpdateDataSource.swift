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

final class LastUpdateDataSource: DataSource {

    struct Settings: DataSourceSettings & Equatable {

        static let dataSourceType: DataSourceType = .lastUpdate

        var flags: DataItemFlags
        var text: String
    }

    struct SettingsView: View {

        @ObservedObject var model: Model

        var body: some View {
            Form {
                FlagsSection(flags: $model.settings.flags)
            }
            .presents($model.error)
        }

    }

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: LastUpdateDataSource.image,
                                  title: LastUpdateDataSource.name)
        }

    }

    static let id: DataSourceType = .lastUpdate
    static let name = "Last Update"
    static let image = Image(systemName: "clock")
    
    let defaults = Settings(flags: [], text: "")

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        let dateString = dateFormatter.string(from: date)
        completion([DataItem(text: "Last updated \(dateString)", flags: settings.flags)], nil)
    }

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
