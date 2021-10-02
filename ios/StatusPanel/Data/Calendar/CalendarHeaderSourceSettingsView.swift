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
        var settings = settings
        if case .variable(let long, let short) = settings.format {
            _long = State(initialValue: long)
            _short = State(initialValue: short)
        } else {
            // TODO: Common accessor for the defaults?
            settings.format = .variable(long: "yMMMMdEEEE", short: "yMMMMdEEE")
            _long = State(initialValue: "yMMMMdEEEE")
            _short = State(initialValue: "yMMMMdEEE")
        }
        _settings = State(initialValue: settings)
    }

    func offset() -> Binding<Offset> {
        Binding {
            if settings.offset == 0 {
                return .today
            } else {
                return .tomorrow
            }
        } set: { offset in
            switch offset {
            case .today:
                settings.offset = 0
                settings.component = .day
            case .tomorrow:
                settings.offset = 1
                settings.component = .day
            }
            try! store.save(settings: settings)
        }
    }

    var date: Date {
        Calendar.current.date(byAdding: settings.component, value: settings.offset, to: Date())!
    }

    func preview(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate(format)
        return dateFormatter.string(from: date)
    }

    var body: some View {
        Form {
            Section {
                Text(preview(format: long))
                    .frame(maxWidth: .infinity)
            }
            Section {
                Picker("Date", selection: offset()) {
                    Text("Today").tag(Offset.today)
                    Text("Tomorrow").tag(Offset.tomorrow)
                }
            }
            Section {
                Button {
                    format = .year
                    long = "y"
                    short = "y"
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
            } header: {
                Text("Format")
            }
            if case .custom = format {
                Section {
                    TextField("Long", text: $long)
                    TextField(long.isEmpty ? "Short" : long, text: $short)
                }
                .autocapitalization(.none)
            }
        }
    }

}
