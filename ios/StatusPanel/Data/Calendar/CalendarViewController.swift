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

import EventKit
import SwiftUI
import UIKit

class CalendarViewController: UITableViewController {

    var store: DataSourceSettingsStore<CalendarSource.Settings>!
    var settings: CalendarSource.Settings!

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
            return 2 + (settings.showLocations ? 1 : 0)
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
            switch indexPath.row {
            case 0:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.textLabel?.text = "Day"
                cell.detailTextLabel?.text = LocalizedOffset(settings.offset)
                cell.accessoryType = .disclosureIndicator
                return cell
            case 1:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Show locations"
                let control = UISwitch()
                control.isOn = settings.showLocations
                control.addTarget(self, action:#selector(showCalendarLocationsSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
                return cell
            case 2:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Show full URLs in locations"
                let control = UISwitch()
                control.isOn = settings.showUrls
                control.addTarget(self, action:#selector(showUrlsInCalendarLocationsSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
                return cell
            default:
                break
            }
            assert(false)
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
        if indexPath.section >= calendars.count {
            return indexPath.row == 0
        }
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section >= calendars.count {
            if indexPath.row == 0 {
                let viewController = UIHostingController(rootView: DayPicker(offset: settings.offset, completion: { offset in
                    self.settings.offset = offset
                    try! self.store.save(settings: self.settings)
                    self.navigationController?.popToViewController(self, animated: true)
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                }))
                viewController.title = "Day"
                navigationController?.pushViewController(viewController, animated: true)
            }
        } else {
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

    @objc func showCalendarLocationsSwitchChanged(sender: UISwitch) {
        settings.showLocations = sender.isOn
        do {
            try store.save(settings: settings)
        } catch {
            self.present(error: error)
        }
        tableView.performBatchUpdates({
            let redactUrlsIndexPath = IndexPath(row: 2, section: calendars.count)
            if settings.showLocations {
                tableView.insertRows(at: [redactUrlsIndexPath], with: .automatic)
            } else {
                tableView.deleteRows(at: [redactUrlsIndexPath], with: .automatic)
            }
        })
    }

    @objc func showUrlsInCalendarLocationsSwitchChanged(sender: UISwitch) {
        settings.showUrls = sender.isOn
        do {
            try store.save(settings: settings)
        } catch {
            self.present(error: error)
        }
    }
}
