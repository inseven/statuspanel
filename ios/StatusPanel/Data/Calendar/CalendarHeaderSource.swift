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
import SwiftUI
import UIKit

final class CalendarHeaderSource : DataSource {

    struct Settings: DataSourceSettings & Equatable {

        static func == (lhs: CalendarHeaderSource.Settings, rhs: CalendarHeaderSource.Settings) -> Bool {
            return (lhs.longFormat == rhs.longFormat &&
                    lhs.shortFormat == rhs.shortFormat &&
                    lhs.flags == rhs.flags &&
                    lhs.offset == rhs.offset &&
                    lhs.component == rhs.component)
        }

        var longFormat: String
        var shortFormat: String

        var flags: DataItemFlags

        var offset: Int
        var component: Calendar.Component

        init(longFormat: String = "yMMMMdEEEE",
             shortFormat: String = "yMMMMdEEE",
             flags: DataItemFlags = [],
             offset: Int = 0,
             component: Calendar.Component = .day) {
            self.longFormat = longFormat
            self.shortFormat = shortFormat
            self.flags = flags
            self.offset = offset
            self.component = component
        }

    }

    class CalendarHeaderItem : DataItemBase {

        let date: Date

        let longFormat: String
        let shortFormat: String

        let flags: DataItemFlags

        init(date: Date, longFormat: String, shortFormat: String, flags: DataItemFlags) {
            self.date = date
            self.longFormat = longFormat
            self.shortFormat = shortFormat
            self.flags = flags
        }

        var icon: String? { nil }

        var prefix: String { "" }

        var subText: String? { nil }

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

    let id: DataSourceType = .calendarHeader
    let name = "Date"
    let configurable = true

    var defaults: Settings { CalendarHeaderSource.Settings() }

    init() {
    }

    func data(settings: Settings, completion: @escaping (CalendarHeaderSource, [DataItemBase], Error?) -> Void) {

        guard let date = Calendar.current.date(byAdding: settings.component, value: settings.offset, to: Date()) else {
            completion(self, [], StatusPanelError.invalidDate)
            return
        }

        let data = [CalendarHeaderItem(date: date,
                                       longFormat: settings.longFormat,
                                       shortFormat: settings.shortFormat,
                                       flags: settings.flags)]
        completion(self, data, nil)
    }

    func summary(settings: Settings) -> String? {
        settings.offset.localizedOffset
    }

    func settingsViewController(store: Store, settings: Settings) -> UIViewController? { nil }

    func settingsView(store: Store, settings: Settings) -> some View {
        CalendarHeaderSourceSettingsView(store: store, settings: settings)
    }

}
