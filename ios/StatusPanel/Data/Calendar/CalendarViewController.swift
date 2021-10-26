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
    
    private static var cellReuseIdentifier = "Cell"

    private let config: Config
    private let store: DataSourceSettingsStore<CalendarSource.Settings>
    private var settings: CalendarSource.Settings
    private let eventStore: EKEventStore

    private var activeCalendars: Set<String> = []

    init(config: Config, store: DataSourceSettingsStore<CalendarSource.Settings>, settings: CalendarSource.Settings) {
        self.config = config
        self.store = store
        self.settings = settings
        self.eventStore = EKEventStore()
        super.init(style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        activeCalendars = Set(config.activeCalendars)
        super.viewWillAppear(animated)
    }

    func save() {
        do {
            try store.save(settings: settings)
        } catch {
            self.present(error: error)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3 + (settings.showLocations ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = LocalizedString("calendar_calendars_label")
            let calendarsCountFormat = LocalizedString("calendar_calendars_count_value")
            cell.detailTextLabel?.text = String(format: calendarsCountFormat, activeCalendars.count)
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = LocalizedString("calendar_day_label")
            cell.detailTextLabel?.text = LocalizedOffset(settings.offset)
            cell.accessoryType = .disclosureIndicator
            return cell
        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = LocalizedString("calendar_show_locations_label")
            let control = UISwitch()
            control.isOn = settings.showLocations
            control.addTarget(self,
                              action:#selector(showCalendarLocationsSwitchChanged(sender:)),
                              for: .valueChanged)
            cell.accessoryView = control
            return cell
        case 3:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = LocalizedString("calendar_show_urls_label")
            let control = UISwitch()
            control.isOn = settings.showUrls
            control.addTarget(self,
                              action:#selector(showUrlsInCalendarLocationsSwitchChanged(sender:)),
                              for: .valueChanged)
            cell.accessoryView = control
            return cell
        default:
            break
        }
        fatalError("Unknown index path")
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row == 0 || indexPath.row == 1
    }

    var activeCalendarsBinding: Binding<Set<String>> {
        return Binding {
            return self.activeCalendars
        } set: { newValue in
            self.activeCalendars = newValue
            self.config.activeCalendars = self.activeCalendars.sorted()
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let viewController = CalendarPickerController(eventStore: EKEventStore(), selection: activeCalendarsBinding)
            navigationController?.pushViewController(viewController, animated: true)
        } else if indexPath.row == 1 {
            let viewController = UIHostingController(rootView: DayPicker(offset: settings.offset, completion: { offset in
                self.settings.offset = offset
                self.save()
                self.navigationController?.popToViewController(self, animated: true)
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
            }))
            viewController.title = "Day"
            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    @objc func showCalendarLocationsSwitchChanged(sender: UISwitch) {
        settings.showLocations = sender.isOn
        save()
        tableView.performBatchUpdates({
            let redactUrlsIndexPath = IndexPath(row: 3, section: 0)
            if settings.showLocations {
                tableView.insertRows(at: [redactUrlsIndexPath], with: .automatic)
            } else {
                tableView.deleteRows(at: [redactUrlsIndexPath], with: .automatic)
            }
        })
    }

    @objc func showUrlsInCalendarLocationsSwitchChanged(sender: UISwitch) {
        settings.showUrls = sender.isOn
        save()
    }
}
