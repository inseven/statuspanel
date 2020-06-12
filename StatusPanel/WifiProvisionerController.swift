//
//  WifiProvisionerController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 17/05/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import UIKit
import CoreLocation
import NetworkExtension
import Network

class WifiProvisionerController: UITableViewController, CLLocationManagerDelegate, UITextFieldDelegate {

    // @IBOutlet weak var panelLabel: UILabel!
    @IBOutlet weak var ssidField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var buttonCell: UITableViewCell!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerViewLabel: UILabel!

    let ButtonSection = 1

    private var loc = CLLocationManager()
    private var spot = NEHotspotConfigurationManager.shared
    private var hotspotSsid: String?
    private var hotspotPassword: String?
    private var configuredHotspotCredentials: NEHotspotConfiguration?
    var panelIdentifer: String?
    private var connecting = false
    private var conn: NWConnection?
    private var networkProvisioner: NetworkProvisioner!

    func setHotspotCredentials(ssid: String, password: String) {
        print("Hotspot credentials ssid=\(ssid) password=\(password)")
        hotspotSsid = ssid
        hotspotPassword = password
    }

    func connectToHotspot() {
        let conf = NEHotspotConfiguration(ssid: hotspotSsid!, passphrase: hotspotPassword!, isWEP: false)
        conf.joinOnce = true
        connecting = true
        updateButton()
        spot.apply(conf) { (err: Error?) in
            self.connecting = false
            if err == nil {
                print("Connected to \(conf.ssid)!")
                self.configuredHotspotCredentials = conf
                self.networkProvisioner.configure(ssid: self.ssidField.text!, password: self.passwordField.text!) { result in
                    switch result {
                    case .success:
                        print("Successfully configured network!")
                    case .failure(let error):
                        print("Failed to configure network with error '\(error)'.")
                        DispatchQueue.main.async {
                            self.showError(String(describing: error))
                        }
                    }
                }
            } else {
                self.showError("Failed to connect, \(String(describing: err))")
            }
            self.updateButton()
        }
    }

    @IBAction func textChanged(_ sender: UITextField) {
        updateButton()
    }

    func updateButton() {
        var enable = false
        guard let button = buttonCell.textLabel else {
            return
        }
        if connecting {
            button.text = "Connecting..."
        } else if self.configuredHotspotCredentials != nil {
            button.text = "Provisioning..."
        } else {
            if let ssid = ssidField.text {
                if ssid.count > 0 {
                    enable = true
                    button.text = "Provision"
                } else {
                    button.text = "Enter an SSID"
                }
            }
        }
        buttonCell.isUserInteractionEnabled = enable
        button.textColor = enable ? .label : .secondaryLabel
    }

    @IBAction func cancel() {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        networkProvisioner = NetworkProvisioner(address: "192.168.4.1", port: 9001)
        loc.delegate = self
        ssidField.delegate = self
        passwordField.delegate = self
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = footerView

        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            loc.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            setSSID()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == ssidField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            provision()
        }
        return false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // panelLabel.text = panelIdentifer
        updateButton()
        ssidField.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let creds = configuredHotspotCredentials {
            conn = nil
            spot.removeConfiguration(forSSID: creds.ssid)
            configuredHotspotCredentials = nil
        }
        super.viewDidDisappear(animated)
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == ButtonSection
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == ButtonSection {
            provision()
        }
    }

    func provision() {
        // Better way to do this?
        ssidField.resignFirstResponder()
        passwordField.resignFirstResponder()

//        hotspotSsid = "SSID"
//        hotspotPassword = "PASSWORD"

        if hotspotSsid != nil && hotspotPassword != nil {
            connectToHotspot()
        } else {
            showError("No hotspot credentials to connect to!")
        }
    }

    func showError(_ error: String) {
        footerViewLabel?.text = error
    }

    private func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedWhenInUse) {
            setSSID()
        }
    }

    private func setSSID() {
        ssidField.text = retrieveCurrentSSID()
    }

    // Thanks https://stackoverflow.com/questions/56583650/cncopycurrentnetworkinfo-with-ios-13
    private func retrieveCurrentSSID() -> String? {
        let interfaces = CNCopySupportedInterfaces() as? [String]
        let interface = interfaces?.compactMap { [weak self] in self?.retrieveInterfaceInfo(from: $0) }.first
        return interface
    }

    private func retrieveInterfaceInfo(from interface: String) -> String? {
        guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject],
            let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
            else {
                return nil
        }
        return ssid
    }

}
