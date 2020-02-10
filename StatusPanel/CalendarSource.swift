//
//  CalendarSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation
import EventKit

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

    // Interim solution to clean up the layout of time + title.
    // Ultimately, we would want to replace this with a UIView-based model where we can rely on
    // constraints-based layout to do everything correctly for us.
    // This is clearly a hack, but as long as we're using English, we'll probably get away with it.
    static func formatEvent(time: String?, title: String) -> DataItem {
        guard let time = time else {
            return DataItem(title)
        }

        // We know that we have a full-width of 18 characters to play with.
        // We should therefore remove the width of the time string with padding (presumably 6 characters)
        // and then wrap the remaining text with this.
        let maximumWidth = 18
        let timeWidth = time.count + 1
        var components = title.split(separator: " ")

        var inset = "\(time) "
        var result = ""
        var line = ""
        while components.count > 0 {
            line.append(inset)
            repeat {
                line.append(contentsOf: components.remove(at: 0))
                if (components.count > 0) {
                    line.append(" ")
                }
            } while (components.count > 0 && (line.count + components[0].count + 1) <= maximumWidth)
            if (components.count > 0) {
                line.append("\n")
            }
            result.append(line)
            line = ""
            inset = String(repeating: " ", count: timeWidth)
        }

        return DataItem(result)
    }

    func getData(callback: Callback) {
        let df = DateFormatter()
        df.timeStyle = DateFormatter.Style.short
        let timeZoneFormatter = DateFormatter()
        timeZoneFormatter.dateFormat = "z"

        // TODO: Inject the configuration into the calendar data source.
        let activeCalendars = Config().activeCalendars
        let calendars = eventStore.calendars(for: .event).filter({ activeCalendars.firstIndex(of: $0.calendarIdentifier) != nil })

        let now = Date()
        let cal = Calendar.current
        let dayComponents = cal.dateComponents([.year, .month, .day], from: now)
        let todayStart = cal.date(from: dayComponents)!
        let dayStart = cal.date(byAdding: DateComponents(day: dayOffset), to: todayStart)!
        let tz = cal.timeZone
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart)!
        let pred = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: calendars)
        let events = eventStore.events(matching: pred)
        var results = [DataItem]()
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
                results.append(CalendarSource.formatEvent(time: nil, title: event.title!))
            } else if event.timeZone != nil && event.timeZone != tz {
                // a nil timezone means floating time
                df.timeZone = event.timeZone
                timeZoneFormatter.timeZone = event.timeZone
                let eventLocalTime = df.string(from: event.startDate)
                df.timeZone = tz
                let tzStr = timeZoneFormatter.string(from: event.startDate)
                results.append(CalendarSource.formatEvent(time: timeStr, title: "\(event.title!) (\(eventLocalTime) \(tzStr))"))
            } else {
                results.append(CalendarSource.formatEvent(time: timeStr, title: event.title!))
            }
        }
        callback(self, results, nil)
    }

    static func getHeader() -> DataItem {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")
        let val = df.string(from: Date())
        return DataItem(val, flags: [.header])
    }
}
