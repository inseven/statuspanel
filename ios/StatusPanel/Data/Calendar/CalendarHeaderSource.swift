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
import UIKit

final class CalendarHeaderSource : DataSource {

    struct Settings: DataSourceSettings & Equatable {

        var longFormat: String
        var shortFormat: String
        var offset: Int
        var flags: DataItemFlags

    }

    class CalendarHeaderItem : DataItemBase {

        let date: Date

        let longFormat: String
        let shortFormat: String

        let flags: DataItemFlags

        let accentColor: UIColor? = nil

        init(date: Date, longFormat: String, shortFormat: String, flags: DataItemFlags) {
            self.date = date
            self.longFormat = longFormat
            self.shortFormat = shortFormat
            self.flags = flags
        }

        var icon: String? {
            return nil
        }

        var prefix: String {
            return ""
        }

        var subText: String? {
            return nil
        }

        func getText(checkFit: (String) -> Bool) -> String {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate(longFormat)
            let val = df.string(from: date)
            if !checkFit(val) {
                // Too long, shorten the day name
                df.setLocalizedDateFormatFromTemplate(shortFormat)
                return df.string(from: date)
            } else {
                return val
            }
        }

    }

    struct SettingsView: View {

        @ObservedObject var model: Model

        var body: some View {
            Form {
                Section {
                    Picker("Day", selection: $model.settings.offset) {
                        Text(LocalizedOffset(0)).tag(0)
                        Text(LocalizedOffset(1)).tag(1)
                    }
                    NavigationLink(destination: FormatEditor(settings: $model.settings)) {
                        HStack {
                            Text("Format")
                            Spacer()
                            Text(model.settings.longFormat)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                FlagsSection(flags: $model.settings.flags)
            }
            .presents($model.error)
        }
    }

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: CalendarHeaderSource.image,
                                  title: CalendarHeaderSource.name,
                                  summary: "\(LocalizedOffset(model.settings.offset)): \(model.settings.longFormat)")
        }

    }

    static let id: DataSourceType = .calendarHeader
    static let name = "Date"
    static let image = Image(systemName: "calendar.badge.clock")

    var defaults: Settings {
        return CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                             shortFormat: "yMMMMdEEE",
                                             offset: 0,
                                             flags: [])
    }

    init() {
    }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {

        guard let date = Calendar.current.date(byAdding: .day, value: settings.offset, to: Date()) else {
            completion([], StatusPanelError.invalidDate)
            return
        }

        let data = [CalendarHeaderItem(date: date,
                                       longFormat: settings.longFormat,
                                       shortFormat: settings.shortFormat,
                                       flags: settings.flags)]
        completion(data, nil)
    }

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
