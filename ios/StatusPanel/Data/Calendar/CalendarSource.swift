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

class CalendarItem : DataItemBase {

    let time: String?
    let icon: String?
    let title: String
    let location: String?
    let flags: DataItemFlags

    init(time: String?, icon: String?, title: String, location: String?, flags: DataItemFlags = []) {
        self.time = time
        self.icon = icon
        self.title = title
        self.location = location
        self.flags = flags
    }

    convenience init(time: String?, title: String, location: String?) {
        self.init(time: time, icon: nil, title: title, location: location, flags: [])
    }

    convenience init(icon: String?, title: String, location: String?) {
        self.init(time: nil, icon: icon, title: title, location: location, flags: [])
    }

    var prefix: String { time ?? "" }

    var subText: String? { location }

    func getText(checkFit: (String) -> Bool) -> String {
        return title
    }

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
                onCompletion([], err)
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
            callback([], nil)
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
        if let header = header {
            results.append(DataItem(text: header, flags: [.prefersEmptyColumn]))
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

            // Don't show declined events.
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

            var location = showLocations ? event.location : nil
            if location != nil && shouldRedactUrls {
                location = redactUrls(location!)
            }

            let allDay = event.isAllDay || (event.startDate <= dayStart && event.endDate >= dayEnd)
            if allDay {
                results.append(CalendarItem(icon: event.calendar.type == .birthday ? "🎁" : "🗓",
                                            title: title,
                                            location: location))
            } else {
                var relevantTime: Date = event.startDate
                var timeStr = df.string(from: relevantTime)
                if event.startDate <= dayStart /* And the end time is today */ {
                    relevantTime = event.endDate
                    timeStr = "Ends\n" + df.string(from: relevantTime)
                }

                if event.timeZone != nil && event.timeZone != tz {
                    // a nil timezone means floating time
                    df.timeZone = event.timeZone
                    timeZoneFormatter.timeZone = event.timeZone
                    let eventLocalTime = df.string(from: relevantTime)
                    df.timeZone = tz
                    let tzStr = timeZoneFormatter.string(from: relevantTime)
                    title = "\(title) (\(eventLocalTime) \(tzStr))"
                }
                results.append(CalendarItem(time: timeStr, title: title, location: location))
            }
        }
        callback(results, nil)
    }

    func redactUrls(_ value: String) -> String {
        let urls = StringUtils.regex(value, pattern: "https?://[^ ]+")
        var result = value
        for urlString in urls {
            if let url = URL(string: urlString), let scheme = url.scheme, let host = url.host {
                let newUrl = "\(scheme)://\(host)/…"
                result = result.replacingOccurrences(of: urlString, with: newUrl)
            } else {
                result = result.replacingOccurrences(of: urlString, with: "▒▒▒▒▒▒▒▒▒▒▒▒▒")
            }
        }
        return result
    }

}
