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
import UIKit

protocol SettingsViewControllerDelegate: AnyObject {

    func didDismiss(settingsViewController: SettingsViewController) -> Void

}

class SettingsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {
    let DataSourcesSection = 0
    let UpdateTimeSection = 1
    let DisplaySection = 2
    let NumDisplaySettings = 4
    let FontSection = 3
    let DeviceIdSection = 4

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
        self.dismiss(animated: true, completion: {
            if self.delegate != nil {
                self.delegate?.didDismiss(settingsViewController: self)
            }
        })
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if delegate != nil {
            delegate?.didDismiss(settingsViewController: self)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        devices = Config().devices
        if self.viewIfLoaded != nil {
            self.tableView.reloadData()
        }
        self.navigationController?.presentationController?.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DataSourcesSection:
            #if DEBUG
                return 4
            #else
                return 3
            #endif
        case UpdateTimeSection: return 1
        case DisplaySection:
            return NumDisplaySettings
        case FontSection:
            return Config().availableFonts.count
        case DeviceIdSection:
            var n = devices.count
            if n == 0 {
                n += 1 // For "No devices configured"
            }
            #if DEBUG
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
        case FontSection: return "Font"
        case DeviceIdSection: return "Paired Devices"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case DeviceIdSection:
            guard let lastBackgroundUpdate = Config().lastBackgroundUpdate else {
                return nil
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            return "Last background update at \(dateFormatter.string(from: lastBackgroundUpdate))"
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
                let lineNames = lines.compactMap { TFLDataSource.lines[$0] }
                if !lineNames.isEmpty {
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
            #if DEBUG
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
            let cell = UITableViewCell(style: row == 1 || row == 2  || row == 3 ? .value1 : .default, reuseIdentifier: nil)
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
            case 3:
                cell.textLabel?.text = "Privacy mode"
                switch config.privacyMode {
                case .redactLines:
                    cell.detailTextLabel?.text = "Redact lines"
                case .redactWords:
                    cell.detailTextLabel?.text = "Redact words"
                case .customImage:
                    cell.detailTextLabel?.text = "Custom image"
                }
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        case FontSection:
            let config = Config()
            let font = config.availableFonts[indexPath.row]
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let frame = cell.contentView.bounds.insetBy(dx: cell.separatorInset.left, dy: 0)
            let label = ViewController.getLabel(frame:frame, font: font.configName)
            label.text = font.humanReadableName
            label.sizeToFit()
            label.frame = label.frame.offsetBy(dx: 30, dy: (frame.height - label.bounds.height) / 2)
            if font.configName == config.font {
                cell.imageView?.image = UIImage(systemName: "checkmark")
            }
            cell.contentView.addSubview(label)
            cell.accessoryType = .detailButton
            return cell
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    @objc func columSwitchChanged(sender: UISwitch) {
        Config().displayTwoColumns = sender.isOn
    }

#if DEBUG
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
                vcid = "WifiProvisionerController"
            } else {
                return
            }
        case DisplaySection:
            if indexPath.row == 1 {
                vcid = "DarkModeEditor"
            } else if indexPath.row == 2 {
                vcid = "MaxLinesEditor"
            } else if indexPath.row == 3 {
                vcid = "PrivacyModeEditor"
            }
        case FontSection:
            let config = Config()
            config.font = config.availableFonts[indexPath.row].configName
            tableView.performBatchUpdates({
                var paths: [IndexPath] = []
                for i in 0 ..< config.availableFonts.count {
                    paths.append(IndexPath(row: i, section: FontSection))
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
            if let navvc = vc as? UINavigationController {
                // Hack for presenting the underlying controller, useful for dummy device
                navigationController?.pushViewController(navvc.topViewController!, animated: true)
            } else {
                navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            print("No view controller for \(indexPath)!")
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section != DeviceIdSection || indexPath.row >= devices.count {
            return nil
        }
        let action = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completion) in
            let deviceBeingRemoved = self.devices.remove(at: indexPath.row).0
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.devices.count == 0 {
                    tableView.insertRows(at: [IndexPath(row: 0, section: self.DeviceIdSection)], with: .automatic)
                }
            }, completion: nil)
            let config = Config()
            config.setLastUploadHash(for: deviceBeingRemoved, to: nil)
            config.devices = self.devices
            completion(true)
        }
        let actions = UISwipeActionsConfiguration(actions: [action])
        return actions
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.section == FontSection {
            let vc = storyboard?.instantiateViewController(withIdentifier: "FontInfo") as! FontInfoController
            vc.font = Config().availableFonts[indexPath.row]
            navigationController?.pushViewController(vc, animated: true)
        }
    }

}
