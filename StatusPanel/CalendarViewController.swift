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
    var calendars: [EKCalendar]!
    var activeCalendars: [String]!  // TODO: This should be a set.

    override func viewDidLoad() {
        super.viewDidLoad()
        eventStore = EKEventStore()
        calendars = []
        activeCalendars = []
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        calendars = eventStore.calendars(for: .event).sorted(by: { $0.title.compare($1.title) == .orderedAscending })
        activeCalendars = Config().activeCalendars
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return calendars.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let calendar = calendars[indexPath.row]
        cell.textLabel?.text = calendar.title
        if activeCalendars.contains(calendar.calendarIdentifier) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let calendar = calendars[indexPath.row]
        if activeCalendars.contains(calendar.calendarIdentifier) {
            activeCalendars.remove(at: activeCalendars.firstIndex(of: calendar.calendarIdentifier)!)
        } else {
            activeCalendars.append(calendar.calendarIdentifier)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .fade)
        Config().activeCalendars = activeCalendars
    }

}
