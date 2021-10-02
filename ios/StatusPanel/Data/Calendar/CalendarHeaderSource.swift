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

    enum DateFormat: Codable {

        case fixed(format: String)
        case variable(long: String, short: String)

    }

    struct Settings: DataSourceSettings {

        var format: DateFormat
        var offset: Int
        var component: Calendar.Component

        init(format: DateFormat = .fixed(format: "YYYY"),
             offset: Int = 0,
             component: Calendar.Component = .day) {
            self.format = format
            self.offset = offset
            self.component = component
        }

    }

    class CalendarHeaderItem : DataItemBase {

        let date: Date
        let format: DateFormat
        let flags: DataItemFlags

        init(for date: Date, format: DateFormat, flags: DataItemFlags) {
            self.date = date
            self.format = format
            self.flags = flags
        }

        var icon: String? { nil }

        var prefix: String { "" }

        var subText: String? { nil }

        var shortFormat: String {
            switch format {
            case .fixed(let format):
                return format
            case .variable(long: _, short: let short):
                return short
            }
        }

        var longFormat: String {
            switch format {
            case .fixed(let format):
                return format
            case .variable(long: let long, short: _):
                return long
            }
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

    let name = "Date Header"
    let configurable = true

    let flags: DataItemFlags
    let defaults: Settings

    init(defaults: Settings,
         flags: DataItemFlags,
         offset: Int = 0,
         component: Calendar.Component = .day) {
        self.defaults = defaults
        self.flags = flags
    }

    func data(settings: Settings, completion: @escaping (CalendarHeaderSource, [DataItemBase], Error?) -> Void) {

        guard let date = Calendar.current.date(byAdding: settings.component, value: settings.offset, to: Date()) else {
            completion(self, [], StatusPanelError.invalidDate)
            return
        }
        
        let data = [CalendarHeaderItem(for: date, format: settings.format, flags: flags)]
        completion(self, data, nil)
    }

    func summary(settings: Settings) -> String? { nil }

    func settingsViewController(settings: Settings, store: Store) -> UIViewController? { nil }

    func settingsView(settings: Settings, store: Store) -> some View {
        CalendarHeaderSourceSettingsView(store: store, settings: settings)
    }

}
