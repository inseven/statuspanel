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
    let DeviceSettingsOrAddSourceSection = 1
    let DevicesSection = 2
    let StatusSection = 3
    let AboutSection = 4

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
        case DeviceSettingsOrAddSourceSection:
            return 1
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
        case DeviceSettingsOrAddSourceSection:
            return nil
        case DevicesSection:
            return "Devices"
        case StatusSection:
            return "Status"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        case DeviceSettingsOrAddSourceSection:
            if isEditing {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Add Data Source..."
                return cell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Device Settings"
                cell.accessoryType = .disclosureIndicator
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

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == DevicesSection {
            if indexPath.row == (devices.count == 0 ? 1 : devices.count) {
                return true // The debug add button
            }
            return false
        } else if indexPath.section == DeviceSettingsOrAddSourceSection {
            return true
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
                let viewController = try source.settingsViewController()
                navigationController?.pushViewController(viewController, animated: true)
            } catch {
                self.present(error: error)
            }
            return
        case DeviceSettingsOrAddSourceSection:
            if isEditing {
                addDataSource()
                tableView.deselectRow(at: indexPath, animated: true)
                return
            } else {
                let controller = UIHostingController(rootView: DeviceSettingsView())
                navigationController?.pushViewController(controller, animated: true)
                tableView.deselectRow(at: indexPath, animated: true)
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
                    Credit("Pavlos Vinieratos", url: URL(string: "https://github.com/pvinis"))
                }
            } licenses: {
                LicenseGroup("Fonts") {
                    for license in Fonts.licenses {
                        license
                    }
                }
                LicenseGroup("Licenses", includeDiligenceLicense: true) {
                    License(name: "Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool.txt")
                    License(name: "StatusPanel", author: "Jason Morley, Tom Sutcliffe", filename: "StatusPanel.txt")
                    License(name: "Swift-Sodium", author: "Frank Denis", filename: "Swift-Sodium.txt")
                }
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

    func addDataSourceControllerDidComplete(_ addDataSourceController: AddDataSourceController) {
        let indexPath = IndexPath(row: self.dataSourceController.instances.count - 1, section: 0)
        self.tableView.insertRows(at: [indexPath], with: .none)
    }

}
