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

    private var eventStore: EKEventStore!
    private var calendars: [[EKCalendar]]!
    private var sources: [EKSource]!
    private var activeCalendars: Set<String>!

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
        return sources.count + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == calendars.count {
            return 1 + (Config().showCalendarLocations ? 1 : 0)
        }
        return calendars[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == calendars.count {
            return "Options"
        }
        return sources[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == calendars.count {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Show locations"
                let control = UISwitch()
                control.isOn = Config().showCalendarLocations
                control.addTarget(self, action:#selector(showCalendarLocationsSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
            case 1:
                cell.textLabel?.text = "Show URLs in locations"
                let control = UISwitch()
                control.isOn = Config().showUrlsInCalendarLocations
                control.addTarget(self, action:#selector(showUrlsInCalendarLocationsSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
            default:
                break
            }
            return cell
        }
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

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section < calendars.count
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

    @objc func showCalendarLocationsSwitchChanged(sender: UISwitch) {
        let config = Config()
        config.showCalendarLocations = sender.isOn
        tableView.performBatchUpdates({
            let redactUrlsIndexPath = IndexPath(row: 1, section: calendars.count)
            if config.showCalendarLocations {
                tableView.insertRows(at: [redactUrlsIndexPath], with: .automatic)
            } else {
                tableView.deleteRows(at: [redactUrlsIndexPath], with: .automatic)
            }
        })
    }

    @objc func showUrlsInCalendarLocationsSwitchChanged(sender: UISwitch) {
        Config().showUrlsInCalendarLocations = sender.isOn
    }
}
