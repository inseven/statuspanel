//
//  CalendarSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation
import EventKit

class CalendarHeader : DataItemBase {
    init(for date: Date) {
        self.date = date
    }
    func format(width: Int) -> String {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")
        let val = df.string(from: date)
        if val.count > width {
            // Too long, shorten the day name
            df.setLocalizedDateFormatFromTemplate("yMMMMdEEE")
            return df.string(from: date)
        } else {
            return val
        }
    }

    func getFlags() -> Set<DataItemFlag> {
        return [.header]
    }

    let date: Date
}

class CalendarItem : DataItemBase {
    init(time: String?, title: String) {
        self.time = time
        self.title = title
    }
    init(title: String) {
        self.time = nil
        self.title = title
    }

    func getFlags() -> Set<DataItemFlag> {
        return []
    }

    func format(width: Int) -> String {
        guard let time = time else {
            return title
        }

        let inset = String(repeating: " ", count: time.count + 1)
        return StringUtils.splitLine("\(time) \(title)", maxChars: width, inset: inset).joined(separator: "\n")
    }

    let time: String?
    let title: String
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

            let timeStr = df.string(from: event.startDate)
            if event.isAllDay {
                results.append(CalendarItem(title: event.title!))
            } else if event.timeZone != nil && event.timeZone != tz {
                // a nil timezone means floating time
                df.timeZone = event.timeZone
                timeZoneFormatter.timeZone = event.timeZone
                let eventLocalTime = df.string(from: event.startDate)
                df.timeZone = tz
                let tzStr = timeZoneFormatter.string(from: event.startDate)
                results.append(CalendarItem(time: timeStr, title: "\(event.title!) (\(eventLocalTime) \(tzStr))"))
            } else {
                results.append(CalendarItem(time: timeStr, title: event.title!))
            }
        }
        callback(self, results, nil)
    }

    static func getHeader() -> DataItemBase {
        return CalendarHeader(for: Date())
    }
}

