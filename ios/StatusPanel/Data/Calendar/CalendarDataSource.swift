// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

import Combine
import Foundation
import EventKit
import SwiftUI

class CalendarItem : DataItemBase {

    let time: String?
    let icon: String?
    let title: String
    let location: String?
    let flags: DataItemFlags
    let accentColor: UIColor?

    init(time: String?,
         icon: String?,
         title: String,
         location: String?,
         flags: DataItemFlags = [],
         accentColor: UIColor?) {
        self.time = time
        self.icon = icon
        self.title = title
        self.location = location
        self.flags = flags
        self.accentColor = accentColor
    }

    convenience init(time: String?, title: String, location: String?, accentColor: UIColor?) {
        self.init(time: time, icon: nil, title: title, location: location, flags: [], accentColor: accentColor)
    }

    convenience init(icon: String?, title: String, location: String?, accentColor: UIColor?) {
        self.init(time: nil, icon: icon, title: title, location: location, flags: [], accentColor: accentColor)
    }

    var prefix: String { time ?? "" }

    var subText: String? { location }

    func getText(checkFit: (String) -> Bool) -> String {
        return title
    }

}

final class CalendarDataSource : DataSource {

    struct Settings: DataSourceSettings, Equatable {

        enum CodingKeys: String, CodingKey {
            case showLocations
            case showUrls
            case offset
            case activeCalendars
        }

        static let dataSourceType: DataSourceType = .calendar

        var showLocations: Bool
        var showUrls: Bool
        var offset: Int
        var activeCalendars: Set<String>

        var calendarNames: String {
            let eventStore = EKEventStore()
            let calendarNames = activeCalendars.compactMap { eventStore.calendar(withIdentifier:$0)?.title }
            guard calendarNames.count > 0 else {
                return "No Calendars Selected"
            }
            return calendarNames.joined(separator: ", ")
        }

        init(showLocations: Bool, showUrls: Bool, offset: Int, activeCalendars: Set<String>) {
            self.showLocations = showLocations
            self.showUrls = showUrls
            self.offset = offset
            self.activeCalendars = activeCalendars
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showLocations = try container.decode(Bool.self, forKey: .showLocations)
            showUrls = try container.decode(Bool.self, forKey: .showUrls)
            offset = try container.decode(Int.self, forKey: .offset)
            if container.contains(.activeCalendars) {
                activeCalendars = Set(try container.decode([String].self, forKey: .activeCalendars))
            } else {
                activeCalendars = Set(Config.shared.activeCalendars)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(showLocations, forKey: .showLocations)
            try container.encode(showUrls, forKey: .showUrls)
            try container.encode(offset, forKey: .offset)
            try container.encode(Array(activeCalendars), forKey: .activeCalendars)
        }

    }

    typealias SettingsView = CalendarSettingsView

    struct SettingsItem: View {

        @ObservedObject var model: Model

        var body: some View {
            DataSourceInstanceRow(image: CalendarDataSource.image,
                                  title: CalendarDataSource.name,
                                  summary: "\(LocalizedOffset(model.settings.offset)): \(model.settings.calendarNames)")
        }

    }

    static let id: DataSourceType = .calendar
    static let name = "Calendar"
    static let image = Image(systemName: "calendar")

    let eventStore: EKEventStore

    var defaults: Settings {
        return Settings(showLocations: false,
                        showUrls: false,
                        offset: 0,
                        activeCalendars: [])
    }

    init() {
        eventStore = EKEventStore()
    }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {
        eventStore.requestAccessToEvents { (granted: Bool, err: Error?) in
            if (granted) {
                self.getData(settings: settings, callback: completion)
            } else {
                completion([], err)
            }
        }
    }

    func getData(settings: Settings, callback: ([DataItemBase], Error?) -> Void) {
        let df = DateFormatter()
        df.timeStyle = DateFormatter.Style.short
        let timeZoneFormatter = DateFormatter()
        timeZoneFormatter.dateFormat = "z"

        let calendars = eventStore
            .calendars(for: .event)
            .filter({ settings.activeCalendars.firstIndex(of: $0.calendarIdentifier) != nil })
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
        let dayStart = cal.date(byAdding: DateComponents(day: settings.offset), to: todayStart)!
        let tz = cal.timeZone
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart)!
        let pred = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: calendars)
        let events = eventStore.events(matching: pred)
        var results = [DataItemBase]()

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

            var location = settings.showLocations ? event.location : nil
            if location != nil && !settings.showUrls {
                location = redactUrls(location!)
            }

            let allDay = event.isAllDay || (event.startDate <= dayStart && event.endDate >= dayEnd)
            if allDay {
                results.append(CalendarItem(icon: event.calendar.type == .birthday ? "🎁" : "🗓",
                                            title: title,
                                            location: location,
                                            accentColor: event.uiColor))
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
                results.append(CalendarItem(time: timeStr,
                                            title: title,
                                            location: location,
                                            accentColor: event.uiColor))
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

    func settingsView(model: Model) -> SettingsView {
        return SettingsView(model: model)
    }

    func settingsItem(model: Model) -> SettingsItem {
        return SettingsItem(model: model)
    }

}
