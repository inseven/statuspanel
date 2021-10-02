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

class CalendarHeaderSource : DataSource {

    class CalendarHeaderItem : DataItemBase {

        let date: Date

        let longFormat: String
        let shortFormat: String

        let flags: DataItemFlags

        init(for date: Date, longFormat: String, shortFormat: String, flags: DataItemFlags) {
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

    let longFormat: String
    let shortFormat: String
    let offset: Int
    let component: Calendar.Component
    let flags: DataItemFlags

    init(longFormat: String,
         shortFormat: String,
         flags: DataItemFlags,
         offset: Int = 0,
         component: Calendar.Component = .day) {
        self.longFormat = longFormat
        self.shortFormat = shortFormat
        self.flags = flags
        self.component = component
        self.offset = offset
    }

    func fetchData(onCompletion: @escaping Callback) {

        guard let date = Calendar.current.date(byAdding: component, value: offset, to: Date()) else {
            onCompletion(self, [], StatusPanelError.invalidDate)
            return
        }
        
        let data = [CalendarHeaderItem(for: date, longFormat: longFormat, shortFormat: shortFormat, flags: flags)]
        onCompletion(self, data, nil)
    }

}
