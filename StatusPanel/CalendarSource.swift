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
    let dayStart : Date
    let header : String?

    init(forDayOffset dayOffset: Int = 0, header: String? = nil) {
        eventStore = EKEventStore()
        let now = Date()
        let cal = Calendar.current
        let dayComponents = cal.dateComponents([.year, .month, .day], from: now)
        let todayStart = cal.date(from: dayComponents)!
        dayStart = cal.date(byAdding: DateComponents(day: dayOffset), to: todayStart)!
        self.header = header
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
        let calendars: [EKCalendar]? = nil // TODO allow controlling of which calendars to check?
        let cal = Calendar.current
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

            var timeStr = df.string(from: event.startDate)
            if event.isAllDay {
                results.append(DataItem("\(event.title!)"))
            } else if event.timeZone != nil && event.timeZone != tz {
                // a nil timezone means floating time
                df.timeZone = event.timeZone
                timeZoneFormatter.timeZone = event.timeZone
                let eventLocalTime = df.string(from: event.startDate)
                df.timeZone = tz
                let tzStr = timeZoneFormatter.string(from: event.startDate)
                timeStr = "\(timeStr) (\(eventLocalTime) \(tzStr))"
                results.append(DataItem("\(timeStr): \(event.title!)"))
            } else {
                results.append(DataItem("\(timeStr): \(event.title!)"))
            }
        }
        callback(self, results, nil)
    }

    static func getHeader() -> DataItem {
        let df = DateFormatter()
        //df.dateStyle = .long
        df.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")
        let val = df.string(from: Date())
        return DataItem(val, flags: [.header])
    }
}
