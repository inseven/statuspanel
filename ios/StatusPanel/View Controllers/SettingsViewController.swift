// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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

import Diligence

protocol SettingsViewControllerDelegate: AnyObject {

    func didDismiss(settingsViewController: SettingsViewController) -> Void

}

class SettingsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {

    static let datePickerCellReuseIdentifier = "DatePickerCell"

    let DataSourcesSection = 0
    let ScheduleOrAddSourceSection = 1
    let DisplaySettingsSection = 2
    let FontsSection = 3
    let DevicesSection = 4
    let StatusSection = 5
    let AboutSection = 6

    let DisplaySettingsRowCount = 5

    weak var delegate: SettingsViewControllerDelegate?

    var devices: [Device] = []

    var doneButtonItem: UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .done,
                               target: self,
                               action: #selector(cancelTapped(_:)))
    }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItem = doneButtonItem
        tableView.allowsSelectionDuringEditing = true
        title = "Settings"

        tableView.register(DatePickerTableViewCell.self, forCellReuseIdentifier: Self.datePickerCellReuseIdentifier)
    }

    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true) {
            self.delegate?.didDismiss(settingsViewController: self)
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        guard editing != self.isEditing else {
            return
        }
        super.setEditing(editing, animated: animated)
        if editing {
            self.navigationItem.setRightBarButton(nil, animated: true)
            tableView.performBatchUpdates {
                tableView.deleteSections([1, 2, 3, 4, 5, 6], with: .fade)
                tableView.insertSections([1], with: .fade)
            }
        } else {
            self.navigationItem.setRightBarButton(doneButtonItem, animated: true)
            tableView.performBatchUpdates {
                tableView.deleteSections([1], with: .fade)
                tableView.insertSections([1, 2, 3, 4, 5, 6], with: .fade)
            }
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        delegate?.didDismiss(settingsViewController: self)
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
        if isEditing {
            return 2
        } else {
            return 7
        }
    }

    var dataSourceController: DataSourceController {
        return AppDelegate.shared.sourceController
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DataSourcesSection:
            return dataSourceController.instances.count
        case ScheduleOrAddSourceSection:
            return 1
        case DisplaySettingsSection:
            return DisplaySettingsRowCount
        case FontsSection:
            return 2
        case DevicesSection:
            var n = devices.count
            if n == 0 {
                n += 1 // For "No devices configured"
            }
            n += 1 // For "Add demo device"
            return n
        case StatusSection:
            return 1
        case AboutSection:
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case DataSourcesSection: return "Layout"
        case ScheduleOrAddSourceSection:
            if isEditing {
                return nil
            } else {
                return "Schedule"
            }
        case DisplaySettingsSection:
            return "Display"
        case FontsSection:
            return "Fonts"
        case DevicesSection:
            return "Devices"
        case StatusSection:
            return "Status"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let config = Config()
        switch indexPath.section {
        case DataSourcesSection:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DataSourceCell")
            cell.imageView?.contentMode = .center
            cell.imageView?.tintColor = UIColor.label
            let source = dataSourceController.instances[indexPath.row]
            cell.imageView?.image = source.dataSource.image
            cell.textLabel?.text = source.dataSource.name
            do {
                cell.detailTextLabel?.text = try source.dataSource.summary(for: source.id)
            } catch {
                cell.detailTextLabel?.text = error.localizedDescription
            }
            cell.accessoryType = source.dataSource.configurable ? .disclosureIndicator : .none
            cell.showsReorderControl = true
            return cell
        case ScheduleOrAddSourceSection:
            if isEditing {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Add Data Source..."
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.datePickerCellReuseIdentifier,
                                                         for: indexPath) as! DatePickerTableViewCell
                cell.label.text = "Device Update Time"
                cell.datePicker.datePickerMode = .time
                cell.datePicker.timeZone = TimeZone(secondsFromGMT: 0)
                cell.datePicker.date = Date.init(timeIntervalSinceReferenceDate: Config().updateTime)
                cell.datePicker.addTarget(self,
                                          action: #selector(updateTimeChanged(sender:forEvent:)),
                                          for: .valueChanged)
                return cell
            }
        case DevicesSection:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DeviceCell")
            if devices.count == 0 && indexPath.row == 0 {
                cell.textLabel?.text = LocalizedString("settings_no_devices_label")
                cell.textLabel?.textColor = .secondaryLabel
            } else if indexPath.row >= devices.count {
                cell.textLabel?.text = LocalizedString("settings_add_dummy_device_label")
                cell.textLabel?.textColor = .label
            } else {
                let device = devices[indexPath.row]
                cell.textLabel?.text = "\(device.kind.description)"
                cell.detailTextLabel?.text = device.id
                cell.textLabel?.textColor = .label
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
                cell.detailTextLabel?.text = Localize(config.darkMode)
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
            textLabel.font = UIFont.preferredFont(forTextStyle: .body)
            textLabel.adjustsFontForContentSizeCategory = true
            cell.contentView.addSubview(textLabel)

            let config = Config()
            let fontName = indexPath.row == 0 ? config.titleFont : config.bodyFont
            let font = config.getFont(named: fontName)
            let fontLabel = UILabel.getLabel(frame: .zero, font: font.configName, style: .text)
            fontLabel.text = font.humanReadableName
            fontLabel.translatesAutoresizingMaskIntoConstraints = false
            fontLabel.textColor = .secondaryLabel
            cell.contentView.addSubview(fontLabel)

            NSLayoutConstraint.activate([

                textLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                textLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),

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

        case StatusSection:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = LocalizedString("settings_last_background_update_label")
            if let lastBackgroundUpdate = Config().lastBackgroundUpdate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                cell.detailTextLabel?.text = dateFormatter.string(from: lastBackgroundUpdate)
            } else {
                cell.detailTextLabel?.text = LocalizedString("settings_last_background_update_value_never")
            }
            return cell
        case AboutSection:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "About StatusPanel..."
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

    @objc func updateTimeChanged(sender: UIDatePicker, forEvent event: UIEvent) {
        let newTime = sender.date.timeIntervalSinceReferenceDate
        Config().updateTime = newTime
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == DevicesSection {
            if indexPath.row == (devices.count == 0 ? 1 : devices.count) {
                return true // The debug add button
            }
            return false
        } else if indexPath.section == ScheduleOrAddSourceSection {
            return isEditing
        } else if indexPath.section == DisplaySettingsSection {
            return indexPath.row > 1
        } else if indexPath.section == DataSourcesSection {
            return dataSourceController.instances[indexPath.row].dataSource.configurable
        } else if indexPath.section == StatusSection {
            return false
        } else {
            // All others are highlightable
            return true
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == DataSourcesSection
    }

    override func tableView(_ tableView: UITableView,
                            targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                            toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Ensure rows cannot be moved outside of their own section.
        if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
            return sourceIndexPath
        } else {
            return proposedDestinationIndexPath
        }
    }

    override func tableView(_ tableView: UITableView,
                            moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        let dataSource = dataSourceController.instances.remove(at: sourceIndexPath.row)
        dataSourceController.instances.insert(dataSource, at: destinationIndexPath.row)
        do {
            try dataSourceController.save()
        } catch {
            self.present(error: error)
        }
    }

    override func tableView(_ tableView: UITableView,
                            canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == DataSourcesSection {
            return true
        } else if indexPath.section == DevicesSection {
            return indexPath.row < devices.count
        }
        return false
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }
        if indexPath.section == DataSourcesSection {
            let dataSource = dataSourceController.instances[indexPath.row]
            dataSourceController.remove(instance: dataSource)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            do {
                try dataSourceController.save()
            } catch {
                present(error: error)
            }
        } else if indexPath.section == DevicesSection {
            // N.B. This is handled by trailingSwipeActionsConfigurationForRowAt instead.
        }
    }

    // Overridden to prevent swipe gestures setting isEditing.
    override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {

    }

    // Overridden to prevent swipe gestures setting isEditing.
    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {

    }

    func addDataSource() {
        let viewController = AddDataSourceController(dataSourceController: dataSourceController)
        viewController.addSourceDelegate = self
        self.navigationController?.present(viewController, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case DataSourcesSection:
            do {
                let source = dataSourceController.instances[indexPath.row]
                guard let viewController = try source.dataSource.settingsViewController(for: source.id) else {
                    return
                }
                navigationController?.pushViewController(viewController, animated: true)
            } catch {
                self.present(error: error)
            }
            return
        case ScheduleOrAddSourceSection:
            if isEditing {
                addDataSource()
                tableView.deselectRow(at: indexPath, animated: true)
                return
            } else {
                return
            }
        case DevicesSection:
            let prevCount = devices.count
            if indexPath.row == (prevCount == 0 ? 1 : prevCount) {
                let device = Device()
                devices.append(device)
                Config().devices = devices
                tableView.performBatchUpdates {
                    tableView.deselectRow(at: indexPath, animated: true)
                    if prevCount == 0 {
                        tableView.deleteRows(at: [IndexPath(row: prevCount, section: DevicesSection)], with: .fade)
                    }
                    tableView.insertRows(at: [IndexPath(row: prevCount, section: DevicesSection)], with: .fade)
                }
                let operation: ExternalOperation = .registerDeviceAndConfigureWiFi(device, ssid: device.publicKey)
                self.dismiss(animated: true) {
                    self.delegate?.didDismiss(settingsViewController: self)
                    UIApplication.shared.open(operation.url, options: [:])
                }
                return
            } else {
                return
            }
        case DisplaySettingsSection:
            if indexPath.row == 2 {
                let viewController = DarkModeController(config: Config())
                navigationController?.pushViewController(viewController, animated: true)
                return
            } else if indexPath.row == 3 {
                let viewController = MaxLinesController(config: Config())
                navigationController?.pushViewController(viewController, animated: true)
                return
            } else if indexPath.row == 4 {
                let viewController = PrivacyModeController(config: Config())
                navigationController?.pushViewController(viewController, animated: true)
                return
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

            let aboutView = AboutView(copyright: "Copyright © 2018-2023\nJason Morley, Tom Sutcliffe") {
                Action("InSeven Limited", url: URL(string: "https://inseven.co.uk")!)
                Action("GitHub", url: URL(string: "https://github.com/inseven/statuspanel")!)
            } acknowledgements: {
                Acknowledgements("Developers") {
                    Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk"))
                    Credit("Tom Sutcliffe", url: URL(string: "https://github.com/tomsci"))
                }
                Acknowledgements("Thanks") {
                    Credit("Lukas Fittl")
                    Credit("Pavlos Vinieratos")
                }
            } licenses: {
                License(name: "Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool.txt")
                License(name: "Diligence", author: "InSeven Limited", filename: "Diligence.txt")
                License(name: "StatusPanel", author: "Jason Morley, Tom Sutcliffe", filename: "StatusPanel.txt")
                License(name: "Swift-Sodium", author: "Frank Denis", filename: "Swift-Sodium.txt")
            }
            let view = UIHostingController(rootView: aboutView)
            present(view, animated: true, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)

        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section != DevicesSection || indexPath.row >= devices.count {
            return nil
        }
        let action = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completion) in
            let deviceBeingRemoved = self.devices.remove(at: indexPath.row).id
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.devices.count == 0 {
                    tableView.insertRows(at: [IndexPath(row: 0, section: self.DevicesSection)], with: .automatic)
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

extension SettingsViewController: AddDataSourceControllerDelegate {

    func addDataSourceController(_ addDataSourceController: AddDataSourceController,
                                 didCompleteWithDetails details: DataSourceInstance.Details) {
        do {
            try self.dataSourceController.add(details)
            try self.dataSourceController.save()
            let indexPath = IndexPath(row: self.dataSourceController.instances.count - 1, section: 0)
            self.tableView.insertRows(at: [indexPath], with: .none)
            self.navigationController?.dismiss(animated: true, completion: nil)
        } catch {
            present(error: error)
        }
    }

    func addDataSourceControllerDidCancel(_ addDataSourceController: AddDataSourceController) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

}
