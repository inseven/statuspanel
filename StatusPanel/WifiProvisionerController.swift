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
                self.sendCredsToPanel()
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

        if hotspotSsid != nil && hotspotPassword != nil {
            connectToHotspot()
        } else {
            showError("No hotspot credentials to connect to!")
        }
    }

    let queue = DispatchQueue(label: "Client connection Q")
    private var payload: Data?

    func sendCredsToPanel() {
        /*
        let host = NWEndpoint.Host.ipv4(IPv4Address("192.168.4.1")!)
        let port = NWEndpoint.Port(rawValue: 9001)!
        payload = "\(ssidField.text!)\0\(passwordField.text!)".data(using: .utf8)
        let params = NWParameters.tcp
        params.multipathServiceType = .disabled
        conn = NWConnection(host: host, port: port, using: params)
        conn?.stateUpdateHandler = connectionStateChanged(to:)
        recv()
        conn?.start(queue: queue)
        */
        let sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
        var address = sockaddr_in()
        address.sin_len = 0
        address.sin_family = UInt8(AF_INET)
        address.sin_port = 0x2923 // 9001 big-endianed
        inet_pton(AF_INET, "192.168.4.1", &address.sin_addr)
        print(address.sin_addr)
        let result: Int32 = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                return connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }
        print("connect returned \(result) errno=\(errno)")
        close(sock)
    }

    func recv() {
        conn?.receive(minimumIncompleteLength: 2, maximumLength: 65536) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                print("connection did receive, data: \(data as NSData) string: \(message ?? "-" )")
            }
            if isComplete {
                self.connectionComplete(error: nil)
            } else if let error = error {
                self.connectionComplete(error: error)
            } else {
                self.recv()
            }
        }
    }

    private func connectionComplete(error: Error?) {
        print("connectionComplete \(String(describing:error))")
        conn?.stateUpdateHandler = nil
        conn?.cancel()
        conn = nil
        let errStr = error == nil ? "SUCCESS!" : String(describing: error)

        DispatchQueue.main.async {
//            if let errStr = errStr {
                self.showError(errStr)
//            }
        }
    }

    private func connectionStateChanged(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionComplete(error: error)
        case .ready:
            print("Connection ready")
            conn?.send(content: payload!, completion: .contentProcessed( { error in
                print("Send complete")
                if let error = error {
                    self.conn = nil
                    self.showError(String(describing: error))
                    return
                }
                print("connection sent!")
            }))
        case .failed(let error):
            connectionComplete(error: error)
        default:
            break
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
