//
//  CalendarViewController.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 13/01/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import EventKit
import UIKit

class CalendarViewController: UITableViewController {

    var eventStore: EKEventStore!
    var calendars: [[EKCalendar]]!
    var sources: [EKSource]!
    var activeCalendars: Set<String>!

    override func viewDidLoad() {
        super.viewDidLoad()
        eventStore = EKEventStore()
    }

    override func viewWillAppear(_ animated: Bool) {
        let allSources = eventStore.sources.sorted(by: { $0.title.compare($1.title) == .orderedAscending})
        sources = []
        calendars = []
        for source in allSources {
            let sourceCalendars = source.calendars(for: .event)
            if sourceCalendars.count > 0 {
                sources.append(source)
                calendars.append(sourceCalendars.sorted(by: { $0.title.compare($1.title) == .orderedAscending }))
            }

        }
        activeCalendars = Set(Config().activeCalendars)
        super.viewWillAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sources.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return calendars[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sources[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let calendar = calendars[indexPath.section][indexPath.row]
        cell.textLabel?.text = calendar.title
        if activeCalendars.contains(calendar.calendarIdentifier) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let calendar = calendars[indexPath.section][indexPath.row]
        if activeCalendars.contains(calendar.calendarIdentifier) {
            activeCalendars.remove(calendar.calendarIdentifier)
        } else {
            activeCalendars.insert(calendar.calendarIdentifier)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .fade)
        Config().activeCalendars = activeCalendars.sorted()
    }

}
