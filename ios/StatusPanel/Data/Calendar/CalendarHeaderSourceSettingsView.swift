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

struct CalendarHeaderSourceSettingsView: View {

    enum Offset {
        case today
        case tomorrow
    }

    enum Format {
        case year
        case dayMonth
        case dayMonthYear
        case custom
    }

    var store: SettingsStore<CalendarHeaderSource.Settings>
    @State var settings: CalendarHeaderSource.Settings
    @State var format: Format = .custom
    @State var long: String
    @State var short: String

    init(store: SettingsStore<CalendarHeaderSource.Settings>, settings: CalendarHeaderSource.Settings) {
        self.store = store
        _long = State(initialValue: settings.longFormat)
        _short = State(initialValue: settings.shortFormat)
        _settings = State(initialValue: settings)
    }

    func update() {
        settings.longFormat = long
        settings.shortFormat = short
        try! store.save(settings: settings)
    }

    var body: some View {
        Form {
            Section {
                Picker("Date", selection: $settings.offset) {
                    Text("Today").tag(0)
                    Text("Tomorrow").tag(1)
                }
            }
            FlagsSection(flags: $settings.flags)
            Section(header: Text("Format")) {
                Button {
                    format = .year
                    long = "y"
                    short = "y"
                    update()
                } label: {
                    HStack {
                        Text("Year")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(format == .year ? .accentColor : .clear)
                    }
                }
                Button {
                    format = .dayMonth
                    long = "MMMMd"
                    short = "MMMMd"
                    update()
                } label: {
                    HStack {
                        Text("Day, Month")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(format == .dayMonth ? .accentColor : .clear)
                    }
                }
                Button {
                    format = .dayMonthYear
                    long = "yMMMMdEEEE"
                    short = "yMMMMdEEE"
                    update()
                } label: {
                    HStack {
                        Text("Day, Month, Year")
                            .foregroundColor(.primary)
                            .layoutPriority(1)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(format == .dayMonthYear ? .accentColor : .clear)
                    }
                }
                Button {
                    format = .custom
                    update()
                } label: {
                    HStack {
                        Text("Custom")
                            .foregroundColor(.primary)
                        Spacer()
                        if format == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            if case .custom = format {
                Section(header: Text("Long Format"),
                        footer: Text("Preferred format specifier.")) {
                    TextField("Long", text: $long)
                        .transition(.opacity)
                }
                Section(header: Text("Short Format"),
                        footer: Text("Used if the result of the long format specifier is too long to fit on the screen.")) {
                    TextField(long.isEmpty ? "Short" : long, text: $short)
                        .transition(.opacity)
                }
                .autocapitalization(.none)
            }
        }
        .onChange(of: settings) { newSettings in
            try! store.save(settings: newSettings)
        }
    }

}
