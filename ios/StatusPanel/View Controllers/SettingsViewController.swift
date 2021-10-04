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

struct AddDataSourceView: View {

    @Environment(\.presentationMode) var presentationMode

    var sourceController: DataSourceController  // TODO: Environment?

    var completion: (DataSourceWrapper?) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(sourceController.dataSources) { factory in
                    Button {
                        completion(factory)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text(factory.name)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitle("Add Data Source", displayMode: .inline)
        }
    }

}

class SettingsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {

    let DataSourcesSection = 0
    let UpdateTimeSection = 1
    let DisplaySettingsSection = 2
    let FontsSection = 3
    let PairedDevicesSection = 4
    let AboutSection = 5

    let DisplaySettingsRowCount = 5

    weak var delegate: SettingsViewControllerDelegate?

    var devices: [(String, String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped(_:)))
    }

    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: {
            if self.delegate != nil {
                self.delegate?.didDismiss(settingsViewController: self)
            }
        })
    }

    @objc func editTapped(_ sender: Any) {
        tableView.performBatchUpdates {
            self.isEditing = true
            tableView.deleteSections([1, 2, 3, 4, 5], with: .fade)
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                                    target: self,
                                                                    action: #selector(addTapped(_:)))
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                     target: self,
                                                                     action: #selector(endEditingTapped(_:)))
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        } completion: { completion in
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }

    @objc func addTapped(_ sender: Any) {
        let viewController = UIHostingController(rootView: AddDataSourceView(sourceController: dataSourceController) { dataSource in
            guard let dataSource = dataSource else {
                return
            }
            // TODO: This should take the factory as an option too.
            // TODO: THis should be fileprivate
            self.dataSourceController.add(type: dataSource.id)
            let indexPath = IndexPath(row: self.dataSourceController.sources.count - 1, section: 0)
            self.tableView.insertRows(at: [indexPath], with: .none)
        })
        navigationController?.present(viewController, animated: true, completion: nil)
    }

    @objc func endEditingTapped(_ sender: Any) {
        tableView.performBatchUpdates {
            self.isEditing = false
            tableView.insertSections([1, 2, 3, 4, 5], with: .fade)
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                    target: self,
                                                                    action: #selector(self.cancelTapped(_:)))
            self.navigationItem.leftBarButtonItem?.isEnabled = false
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit,
                                                                     target: self,
                                                                     action: #selector(editTapped(_:)))
            self.navigationItem.rightBarButtonItem?.isEnabled = false

        } completion: { completion in
            self.navigationItem.leftBarButtonItem?.isEnabled = true
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
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
        if isEditing {
            return 1
        } else {
            return 6
        }
    }

    var dataSourceController: DataSourceController {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        return delegate.sourceController
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DataSourcesSection:
            return dataSourceController.sources.count
        case UpdateTimeSection:
            return 1
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
        case DataSourcesSection: return "Layout"
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
            let source = dataSourceController.sources[indexPath.row]
            cell.textLabel?.text = source.dataSource.name
            cell.detailTextLabel?.text = try? source.dataSource.summary(uuid: source.id) // TODO: make more elegant
            // TODO: Handle error!
            cell.accessoryType = source.dataSource.configurable ? .disclosureIndicator : .none
            cell.showsReorderControl = true
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
        } else if indexPath.section == DataSourcesSection {
            return dataSourceController.sources[indexPath.row].dataSource.configurable
        } else {
            // All others are highlightable
            return true
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == DataSourcesSection else {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView,
                            moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        let dataSource = dataSourceController.sources.remove(at: sourceIndexPath.row)
        dataSourceController.sources.insert(dataSource, at: destinationIndexPath.row)
    }

    override func tableView(_ tableView: UITableView,
                            canEditRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == DataSourcesSection else {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView,
                            canPerformAction action: Selector,
                            forRowAt indexPath: IndexPath,
                            withSender sender: Any?) -> Bool {
        guard indexPath.section == DataSourcesSection else {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vcid: String?
        switch indexPath.section {
        case DataSourcesSection:
            let source = dataSourceController.sources[indexPath.row]
            let uikitViewController = try! source.dataSource.settingsViewController(uuid: source.id)
            if let safeViewController = uikitViewController {
                navigationController?.pushViewController(safeViewController, animated: true)
                return
            }
            // TODO: Common code for presenting an error?
            let viewController = try! source.dataSource.settingsView(uuid: source.id)  // TODO: Handle the throwing
            navigationController?.pushViewController(viewController, animated: true)
            return
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
