//
//  SettingsViewController.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 13/01/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import EventKit
import UIKit

protocol SettingsViewControllerDelegate: AnyObject {

    func didDismiss(settingsViewController: SettingsViewController) -> Void

}

class SettingsViewController: UITableViewController {
    let DataSourcesSection = 0
    let UpdateTimeSection = 1
    let DisplaySection = 2
    let NumDisplaySettings = 3

    let DeviceIdSection = 3

    // These are the view controller storyboard IDs, in IndexPath order
    let DataSourceEditors = [
        "CalendarsEditor",
        "TflEditor",
        "NationalRailEditor"
    ]

    weak var delegate: SettingsViewControllerDelegate?

    var devices: [(String, String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        devices = Config().devices
        if self.viewIfLoaded != nil {
            self.tableView.reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let delegate = delegate else {
            return
        }
        delegate.didDismiss(settingsViewController: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DataSourcesSection:
            #if targetEnvironment(simulator)
                return 4
            #else
                return 3
            #endif
        case UpdateTimeSection: return 1
        case DisplaySection: return NumDisplaySettings + Config().availableFonts.count
        case DeviceIdSection:
            var n = devices.count
            if n == 0 {
                n += 1 // For "No devices configured"
            }
            #if targetEnvironment(simulator)
                n += 1 // For "Add dummy device"
            #endif
            return n
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case DataSourcesSection: return "Data Sources"
        case UpdateTimeSection: return "Update Time"
        case DisplaySection: return "Display Settings"
        case DeviceIdSection: return "Paired Devices"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let config = Config()
        switch indexPath.section {
        case DataSourcesSection:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DataSourceCell")
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Calendars"
                let calendarIds = config.activeCalendars
                let eventStore = EKEventStore()
                var calendarNames: [String] = []
                for calendarId in calendarIds {
                   guard let cal = eventStore.calendar(withIdentifier: calendarId) else {
                       // Calendar has been deleted?
                       continue
                   }
                   calendarNames.append(cal.title)
                }
                if calendarNames.count > 0 {
                    cell.detailTextLabel?.text = calendarNames.joined(separator: ", ")
                } else {
                    cell.detailTextLabel?.text = "None"
                }
            case 1:
                cell.textLabel?.text = "London Underground"
                let lines = config.activeTFLLines
                var lineNames: [String] = []
                for lineId in lines {
                    lineNames.append(TFLDataSource.lines[lineId]!)
                }
                if lineNames.count > 0 {
                    cell.detailTextLabel?.text = lineNames.joined(separator: ", ")
                } else {
                    cell.detailTextLabel?.text = "None"
                }
            case 2:
                cell.textLabel?.text = "National Rail"
                let route = config.trainRoute
                if let from = route.from, let to = route.to {
                    cell.detailTextLabel?.text = "\(from) to \(to)"
                } else {
                    cell.detailTextLabel?.text = "Not configured"
                }
            #if targetEnvironment(simulator)
            case 3:
                cell.textLabel?.text = "Show dummy data"
                let control = UISwitch()
                control.isOn = config.showDummyData
                control.addTarget(self, action:#selector(dummyDataSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
                return cell
            #endif
            default:
                cell.textLabel?.text = "TODO"
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case UpdateTimeSection:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let updateTime = Date(timeIntervalSinceReferenceDate: config.updateTime)
            let df = DateFormatter()
            df.timeStyle = .short
            df.timeZone = TimeZone(secondsFromGMT: 0)
            let timeStr = df.string(from: updateTime)
            cell.textLabel?.text = timeStr
            cell.accessoryType = .disclosureIndicator
            return cell
        case DeviceIdSection:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "DeviceCell")
            if devices.count == 0 && indexPath.row == 0 {
                cell.textLabel?.text = "No devices configured"
            } else if indexPath.row >= devices.count {
                cell.textLabel?.text = "<Add dummy device>"
            } else {
                let device = devices[indexPath.row]
                cell.textLabel?.text = device.0
            }
            return cell
        case DisplaySection:
            let row = indexPath.row
            let cell = UITableViewCell(style: row == 1 || row == 2 ? .value1 : .default, reuseIdentifier: nil)
            switch row {
            case 0:
                cell.textLabel?.text = "Use two columns"
                let control = UISwitch()
                control.isOn = config.displayTwoColumns
                control.addTarget(self, action:#selector(columSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
            case 1:
                cell.textLabel?.text = "Dark mode"
                switch config.darkMode {
                case .off:
                    cell.detailTextLabel?.text = "Off"
                case .on:
                    cell.detailTextLabel?.text = "On"
                case .system:
                    cell.detailTextLabel?.text = "Use system"
                }
                cell.accessoryType = .disclosureIndicator
            case 2:
                cell.textLabel?.text = "Maximum lines per item"
                let val = config.maxLines
                cell.detailTextLabel?.text = val == 0 ? "Unlimited" : String(format: "%d", val)
                cell.accessoryType = .disclosureIndicator
            default:
                let (font, text) = Config().availableFonts[indexPath.row - NumDisplaySettings]
                let frame = cell.contentView.bounds.insetBy(dx: cell.separatorInset.left, dy: 0)
                let view = ViewController.getLabel(frame:frame, font: font)
                view.text = text
                view.sizeToFit()
                view.frame = view.frame.offsetBy(dx: 0, dy: (frame.height - view.bounds.height) / 2)
                cell.accessoryType = (font == Config().font) ? .checkmark : .none
                cell.contentView.addSubview(view)
            }
            return cell
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    @objc func columSwitchChanged(sender: UISwitch) {
        Config().displayTwoColumns = sender.isOn
    }

#if targetEnvironment(simulator)
    @objc func dummyDataSwitchChanged(sender: UISwitch) {
        Config().showDummyData = sender.isOn
    }
#endif

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == DeviceIdSection {
            if indexPath.row == (devices.count == 0 ? 1 : devices.count) {
                return true // The debug add button
            }
            return false
        } else if indexPath.section == DisplaySection {
            return indexPath.row > 0
        } else if indexPath.section == DataSourcesSection && indexPath.row >= DataSourceEditors.count {
            return false
        } else {
            // All others are highlightable
            return true
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vcid: String?
        switch indexPath.section {
        case DataSourcesSection:
            vcid = DataSourceEditors[indexPath.row]
        case UpdateTimeSection:
            vcid = "UpdateTimeEditor"
        case DeviceIdSection:
            let prevCount = devices.count
            if indexPath.row == (prevCount == 0 ? 1 : prevCount) {
                devices.append(("DummyDevice\(indexPath.row)", ""))
                Config().devices = devices
                tableView.performBatchUpdates({
                    tableView.deselectRow(at: indexPath, animated: true)
                    if (prevCount == 0) {
                        tableView.deleteRows(at: [IndexPath(row: prevCount, section: DeviceIdSection)], with: .fade)
                    }
                    tableView.insertRows(at: [IndexPath(row: prevCount, section: DeviceIdSection)], with: .fade)
                }, completion: nil)
            }
            return
        case DisplaySection:
            let config = Config()
            if indexPath.row == 1 {
                vcid = "DarkModeEditor"
                break
            } else if indexPath.row == 2 {
                vcid = "MaxLinesEditor"
                break
            }
            config.font = config.availableFonts[indexPath.row - NumDisplaySettings].0
            tableView.performBatchUpdates({
                var paths: [IndexPath] = []
                for i in 0 ..< config.availableFonts.count {
                    paths.append(IndexPath(row: i+NumDisplaySettings, section: DisplaySection))
                }
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadRows(at: paths, with: .automatic)
            }, completion: nil)
            return
        default:
            break
        }
        if let vcid = vcid {
            guard let vc = storyboard?.instantiateViewController(withIdentifier: vcid) else {
                print("Couldn't find view controller for \(vcid)!")
                return
            }
            navigationController?.pushViewController(vc, animated: true)
        } else {
            print("No view controller for \(indexPath)!")
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section != DeviceIdSection || indexPath.row >= devices.count {
            return nil
        }
        let action = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completion) in
            self.devices.remove(at: indexPath.row)
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.devices.count == 0 {
                    tableView.insertRows(at: [IndexPath(row: 0, section: self.DeviceIdSection)], with: .automatic)
                }
            }, completion: nil)
            Config().devices = self.devices
            completion(true)
        }
        let actions = UISwipeActionsConfiguration(actions: [action])
        return actions
    }

}
