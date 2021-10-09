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

    struct SettingsView: View {

        var store: DataSourceSettingsStore<CalendarHeaderSource.Settings>
        @State var settings: CalendarHeaderSource.Settings
        @State var error: Error? = nil

        init(store: DataSourceSettingsStore<CalendarHeaderSource.Settings>, settings: CalendarHeaderSource.Settings) {
            self.store = store
            _settings = State(initialValue: settings)
        }

        var body: some View {
            Form {
                Section {
                    Picker("Date", selection: $settings.offset) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                    }
                    NavigationLink(destination: FormatEditor(settings: $settings)) {
                        HStack {
                            Text("Format")
                            Spacer()
                            Text(settings.longFormat)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                FlagsSection(flags: $settings.flags)
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

    let id: DataSourceType = .calendarHeader
    let name = "Date"
    let configurable = true

    var defaults: Settings {
        CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
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

    func summary(settings: Settings) -> String? {
        settings.offset.localizedOffset
    }

    func settingsViewController(store: Store, settings: Settings) -> UIViewController? {
        UIHostingController(rootView: SettingsView(store: store, settings: settings))
    }

}
