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
	var eventStore: EKEventStore

	init(eventStore: EKEventStore) {
		self.eventStore = eventStore
	}

	func getData() {
		let df = DateFormatter()
		df.timeStyle = DateFormatter.Style.short
		let timeZoneFormatter = DateFormatter()
		timeZoneFormatter.dateFormat = "z"
		let calendars: [EKCalendar]? = nil // TODO allow controlling of which calendars to check?
		let tz = Calendar.current.timeZone
		let now = Date()
		let pred = eventStore.predicateForEvents(withStart: now, end: now.addingTimeInterval(24*60*60), calendars: calendars)
		let events = eventStore.events(matching: pred)
		var results = [DataItem]()
		for event in events {
			var timeStr = df.string(from: event.startDate)
			if event.timeZone != tz {
				df.timeZone = event.timeZone
				timeZoneFormatter.timeZone = event.timeZone
				let eventLocalTime = df.string(from: event.startDate)
				df.timeZone = tz
				let tzStr = timeZoneFormatter.string(from: event.startDate)
				timeStr = "\(timeStr) (\(eventLocalTime) \(tzStr))"
			}
			results.append(DataItem("\(timeStr): \(event.title!)"))
		}
		print(results)
	}
}
