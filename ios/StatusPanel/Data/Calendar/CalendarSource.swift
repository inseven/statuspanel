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
import EventKit

class CalendarHeader : DataItemBase {
    init(for date: Date) {
        self.date = date
    }

    func getPrefix() -> String {
        return ""
    }

    func getText(checkFit: (String) -> Bool) -> String {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")
        let val = df.string(from: date)
        if !checkFit(val) {
            // Too long, shorten the day name
            df.setLocalizedDateFormatFromTemplate("yMMMMdEEE")
            return df.string(from: date)
        } else {
            return val
        }
    }

    func getSubText() -> String? {
        return nil
    }

    func getFlags() -> Set<DataItemFlag> {
        return [.header]
    }

    let date: Date
}

class CalendarItem : DataItemBase {
    init(time: String?, title: String, location: String?, flags: Set<DataItemFlag> = []) {
        self.time = time
        self.title = title
        self.location = location
        self.flags = flags
    }
    init(title: String, location: String?) {
        self.time = nil
        self.title = title
        self.location = location
        self.flags = []
    }

    func getFlags() -> Set<DataItemFlag> {
        return flags
    }

    func getPrefix() -> String {
        return time ?? ""
    }

    func getText(checkFit: (String) -> Bool) -> String {
        return title
    }

    func getSubText() -> String? {
        return location
    }

    let time: String?
    let title: String
    let location: String?
    let flags: Set<DataItemFlag>
}

class CalendarSource : DataSource {
    let eventStore: EKEventStore
    let header : String?
    let dayOffset: Int

    init(forDayOffset dayOffset: Int = 0, header: String? = nil) {
        eventStore = EKEventStore()
        self.header = header
        self.dayOffset = dayOffset
    }

    func fetchData(onCompletion: @escaping Callback) {
        eventStore.requestAccess(to: EKEntityType.event) { (granted: Bool, err: Error?) in
            if (granted) {
                self.getData(callback: onCompletion)
            } else {
                onCompletion(self, [], err)
            }
            // print("Granted EKEventStore access \(granted) err \(String(describing: err))")
        }
    }

    func getData(callback: Callback) {
        let df = DateFormatter()
        df.timeStyle = DateFormatter.Style.short
        let timeZoneFormatter = DateFormatter()
        timeZoneFormatter.dateFormat = "z"

        let activeCalendars = Config().activeCalendars
        let calendars = eventStore.calendars(for: .event).filter({ activeCalendars.firstIndex(of: $0.calendarIdentifier) != nil })
        if calendars.count == 0 {
            // predicateForEvents treats calendars:[] the same as calendars:nil
            // which matches against _all_ calendars, which we definitely don't
            // want, so we have to return early here.
            callback(self, [], nil)
            return
        }

        let now = Date()
        let cal = Calendar.current
        let dayComponents = cal.dateComponents([.year, .month, .day], from: now)
        let todayStart = cal.date(from: dayComponents)!
        let dayStart = cal.date(byAdding: DateComponents(day: dayOffset), to: todayStart)!
        let tz = cal.timeZone
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart)!
        let pred = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: calendars)
        let events = eventStore.events(matching: pred)
        var results = [DataItemBase]()
        if (header != nil) {
            results.append(DataItem(self.header!, flags: [.header]))
        }

        let config = Config()
        let showLocations = config.showCalendarLocations
        let shouldRedactUrls = !config.showUrlsInCalendarLocations

        for event in events {

            // We want to make sure that we only include calendar types that we support.
            // Unfortunately, it seems like we get calendar types back that we don't yet have
            // symbols for (e.g., suggestions), so we guard against ensuring we receive types
            // we DO understand instead.
            let type = event.calendar.type
            if (type != .birthday &&
                type != .calDAV &&
                type != .exchange &&
                type != .local &&
                type != .subscription) {
                continue
            }

            // Don't show cancelled events.
            if (event.status == .canceled) {
                continue
            }

            // Don't show decliend events.
            var declined = false
            for attendee in event.attendees ?? [] {
                if attendee.isCurrentUser && attendee.participantStatus == .declined {
                    declined = true
                    break
                }
            }
            if declined {
                continue
            }

            // Don't attempt to display calendar entries without a title.
            guard var title = event.title else {
                continue
            }

            // Prefix birthday calendars with a present.
            if event.calendar.type == .birthday {
                title = "🎁 \(title)"
            }

            let timeStr = df.string(from: event.startDate)
            var location = showLocations ? event.location : nil
            if location != nil && shouldRedactUrls {
                location = redactUrls(location!)
            }

            if event.isAllDay {
                results.append(CalendarItem(title: title, location: location))
            } else if event.timeZone != nil && event.timeZone != tz {
                // a nil timezone means floating time
                df.timeZone = event.timeZone
                timeZoneFormatter.timeZone = event.timeZone
                let eventLocalTime = df.string(from: event.startDate)
                df.timeZone = tz
                let tzStr = timeZoneFormatter.string(from: event.startDate)
                results.append(CalendarItem(time: timeStr, title: "\(title) (\(eventLocalTime) \(tzStr))", location: location))
            } else {
                results.append(CalendarItem(time: timeStr, title: title, location: location))
            }
        }
        callback(self, results, nil)
    }

    func redactUrls(_ value: String) -> String {
        let urls = StringUtils.regex(value, pattern: "https?://[^ ]+")
        var result = value
        for urlString in urls {
            if let url = URL(string: urlString), let scheme = url.scheme, let host = url.host {
                let newUrl = "\(scheme)://\(host)/▒▒▒▒▒▒▒▒▒▒▒▒▒"
                result = result.replacingOccurrences(of: urlString, with: newUrl)
            } else {
                result = result.replacingOccurrences(of: urlString, with: "▒▒▒▒▒▒▒▒▒▒▒▒▒")
            }
        }
        return result
    }

    static func getHeader() -> DataItemBase {
        // "Wednesday, 26 February 2020" is a nice long date
        // let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2020, month: 2, day: 26))!
        let date = Date()
        return CalendarHeader(for: date)
    }
}

