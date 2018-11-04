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

    init() {
        eventStore = EKEventStore()
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
        let now = Date()
        let dayComponents = cal.dateComponents([.year, .month, .day], from: now)
        let dayStart = cal.date(from: dayComponents)!
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart)!
        let pred = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: calendars)
        let events = eventStore.events(matching: pred)
        var results = [DataItem]()
        for event in events {
            var timeStr = df.string(from: event.startDate)
            if event.isAllDay {
                timeStr = "All day"
            } else if event.timeZone != nil && event.timeZone != tz {
                // a nil timezone means floating time
                df.timeZone = event.timeZone
                timeZoneFormatter.timeZone = event.timeZone
                let eventLocalTime = df.string(from: event.startDate)
                df.timeZone = tz
                let tzStr = timeZoneFormatter.string(from: event.startDate)
                timeStr = "\(timeStr) (\(eventLocalTime) \(tzStr))"
            }
            results.append(DataItem("\(timeStr): \(event.title!)"))
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
