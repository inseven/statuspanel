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

protocol SettingsViewControllerDelegate: AnyObject {

    func didDismiss(settingsViewController: SettingsViewController) -> Void

}

class SettingsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {

    let DataSourcesSection = 0
    let UpdateTimeSection = 1
    let DisplaySettingsSection = 2
    let FontsSection = 3
    let PairedDevicesSection = 4
    let AboutSection = 5

    let DisplaySettingsRowCount = 5

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
        case DisplaySettingsSection:
            return DisplaySettingsRowCount
        case FontsSection:
            return 2
        case PairedDevicesSection:
            var n = devices.count
            if n == 0 {
                n += 1 // For "No devices configured"
            }
            #if DEBUG
                n += 1 // For "Add dummy device"
            #endif
            return n
        case AboutSection:
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case DataSourcesSection: return "Data Sources"
        case UpdateTimeSection: return "Update Time"
        case DisplaySettingsSection: return "Display Settings"
        case FontsSection: return "Fonts"
        case PairedDevicesSection: return "Paired Devices"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case PairedDevicesSection:
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
                let lineNames = config.activeTFLLines.compactMap { TFLDataSource.lines[$0] }
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
                cell.textLabel?.text = "Show Dummy Data"
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
        case PairedDevicesSection:
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
        case DisplaySettingsSection:
            let row = indexPath.row
            let cell = UITableViewCell(style: row == 2 || row == 3  || row == 4 ? .value1 : .default, reuseIdentifier: nil)
            switch row {
            case 0:
                cell.textLabel?.text = "Use Two Columns"
                let control = UISwitch()
                control.isOn = config.displayTwoColumns
                control.addTarget(self, action:#selector(columSwitchChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
            case 1:
                cell.textLabel?.text = "Show Icons"
                let control = UISwitch()
                control.isOn = config.showIcons
                control.addTarget(self, action:#selector(showIconsChanged(sender:)), for: .valueChanged)
                cell.accessoryView = control
            case 2:
                cell.textLabel?.text = "Dark Mode"
                switch config.darkMode {
                case .off:
                    cell.detailTextLabel?.text = "Off"
                case .on:
                    cell.detailTextLabel?.text = "On"
                case .system:
                    cell.detailTextLabel?.text = "Use System"
                }
                cell.accessoryType = .disclosureIndicator
            case 3:
                cell.textLabel?.text = "Maximum Lines per Item"
                let val = config.maxLines
                cell.detailTextLabel?.text = val == 0 ? "Unlimited" : String(format: "%d", val)
                cell.accessoryType = .disclosureIndicator
            case 4:
                cell.textLabel?.text = "Privacy Mode"
                switch config.privacyMode {
                case .redactLines:
                    cell.detailTextLabel?.text = "Redact Lines"
                case .redactWords:
                    cell.detailTextLabel?.text = "Redact Words"
                case .customImage:
                    cell.detailTextLabel?.text = "Custom Image"
                }
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        case FontsSection:

            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

            let textLabel = UILabel()
            textLabel.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(textLabel)

            let config = Config()
            let fontName = indexPath.row == 0 ? config.titleFont : config.bodyFont
            let font = config.getFont(named: fontName)
            let fontLabel = ViewController.getLabel(frame: .zero, font: font.configName, style: .text)
            fontLabel.text = font.humanReadableName
            fontLabel.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(fontLabel)

            NSLayoutConstraint.activate([
                textLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                textLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            ])

            NSLayoutConstraint.activate([
                fontLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                fontLabel.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor),
                fontLabel.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            ])

            switch indexPath.row {
            case 0:
                textLabel.text = "Title"
            case 1:
                textLabel.text = "Body"
            default:
                break
            }

            cell.accessoryType = .disclosureIndicator

            return cell

        case AboutSection:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "About StatusPanel"
            cell.textLabel?.textColor = UIColor(named: "TintColor")
            return cell
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    @objc func columSwitchChanged(sender: UISwitch) {
        Config().displayTwoColumns = sender.isOn
    }

    @objc func showIconsChanged(sender: UISwitch) {
        Config().showIcons = sender.isOn
    }

#if DEBUG
    @objc func dummyDataSwitchChanged(sender: UISwitch) {
        Config().showDummyData = sender.isOn
    }
#endif

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == PairedDevicesSection {
            if indexPath.row == (devices.count == 0 ? 1 : devices.count) {
                return true // The debug add button
            }
            return false
        } else if indexPath.section == DisplaySettingsSection {
            return indexPath.row > 1
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
        case PairedDevicesSection:
            let prevCount = devices.count
            if indexPath.row == (prevCount == 0 ? 1 : prevCount) {
                devices.append(("DummyDevice\(indexPath.row)", ""))
                Config().devices = devices
                tableView.performBatchUpdates({
                    tableView.deselectRow(at: indexPath, animated: true)
                    if (prevCount == 0) {
                        tableView.deleteRows(at: [IndexPath(row: prevCount, section: PairedDevicesSection)], with: .fade)
                    }
                    tableView.insertRows(at: [IndexPath(row: prevCount, section: PairedDevicesSection)], with: .fade)
                }, completion: nil)
                vcid = "WifiProvisionerController"
            } else {
                return
            }
        case DisplaySettingsSection:
            if indexPath.row == 2 {
                vcid = "DarkModeEditor"
            } else if indexPath.row == 3 {
                vcid = "MaxLinesEditor"
            } else if indexPath.row == 4 {
                vcid = "PrivacyModeEditor"
            }
        case FontsSection:
            switch indexPath.row {
            case 0:
                let viewController = FontPickerViewController("Title Font", font: Binding {
                    Config().titleFont
                } set: { font in
                    Config().titleFont = font
                })
                navigationController?.pushViewController(viewController, animated: true)
            case 1:
                let viewController = FontPickerViewController("Body Font", font: Binding {
                    Config().bodyFont
                } set: { font in
                    Config().bodyFont = font
                })
                navigationController?.pushViewController(viewController, animated: true)
            default:
                break
            }
            return
        case AboutSection:
            let view = UIHostingController(rootView: AboutView())
            present(view, animated: true, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
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
        if indexPath.section != PairedDevicesSection || indexPath.row >= devices.count {
            return nil
        }
        let action = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completion) in
            let deviceBeingRemoved = self.devices.remove(at: indexPath.row).0
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.devices.count == 0 {
                    tableView.insertRows(at: [IndexPath(row: 0, section: self.PairedDevicesSection)], with: .automatic)
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

}
