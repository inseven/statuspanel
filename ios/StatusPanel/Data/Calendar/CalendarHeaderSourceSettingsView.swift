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

    var store: SettingsStore<CalendarHeaderSource.Settings>
    @State var settings: CalendarHeaderSource.Settings

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

    var body: some View {
        Form {
            Section {
                Picker("Date", selection: offset()) {
                    Text("Today").tag(Offset.today)
                    Text("Tomorrow").tag(Offset.tomorrow)
                }
            }
        }
    }

}
