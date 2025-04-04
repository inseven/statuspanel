// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

import UIKit
import CoreLocation
import NetworkExtension

protocol WifiProvisionerViewControllerDelegate: AnyObject {

    func wifiProvisionerViewController(_ wifiProvisionerViewController: WifiProvisionerViewController,
                                       didConfigureDevice device: Device)

}

class WifiProvisionerViewController: UITableViewController, UITextFieldDelegate {

    struct NetworkDetails {
        var ssid: String
        var password: String
    }

    private lazy var ssidCell: TextFieldTableViewCell = {
        let cell = TextFieldTableViewCell()
        cell.textField.placeholder = LocalizedString("setup_wifi_ssid_placeholder")
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.returnKeyType = .next
        return cell
    }()

    private lazy var passwordCell: TextFieldTableViewCell = {
        let cell = TextFieldTableViewCell()
        cell.textField.placeholder = LocalizedString("setup_wifi_password_placeholder")
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.isSecureTextEntry = true
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.returnKeyType = .done
        return cell
    }()

    private lazy var nextButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: LocalizedString("setup_wifi_next_button_title"),
                               style: .done,
                               target: self,
                               action: #selector(nextTapped(sender:)))
    }()

    private lazy var connectingActivityIndicatorItem: UIBarButtonItem = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.startAnimating()
        return UIBarButtonItem(customView: activityIndicator)
    }()

    var networkDetails: NetworkDetails? {
        guard let ssid = self.ssidCell.textField.text,
              !ssid.isEmpty,
              let password = self.passwordCell.textField.text
        else {
            return nil
        }
        return NetworkDetails(ssid: ssid, password: password)
    }

    weak var delegate: WifiProvisionerViewControllerDelegate?

    private var device: Device
    private var hotspotSsid: String
    private var hotspotPassword: String

    private var locationManager = CLLocationManager()
    private var networkConfigurationManager = NEHotspotConfigurationManager.shared
    private var configuredHotspotCredentials: NEHotspotConfiguration?
    private var networkProvisioner = NetworkProvisioner(address: "192.168.4.1", port: 9001)

    private var connecting = false {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            switch connecting {
            case true:
                ssidCell.isUserInteractionEnabled = false
                passwordCell.isUserInteractionEnabled = false
                navigationItem.setRightBarButton(connectingActivityIndicatorItem, animated: true)
            case false:
                ssidCell.isUserInteractionEnabled = true
                passwordCell.isUserInteractionEnabled = true
                navigationItem.setRightBarButton(nextButtonItem, animated: true)
            }
        }
    }

    init(device: Device, ssid: String) {

        self.device = device
        hotspotSsid = ssid
        hotspotPassword = device.publicKey

        super.init(style: .insetGrouped)

        navigationItem.rightBarButtonItem = nextButtonItem
        title = LocalizedString("setup_wifi_title")

        tableView.allowsSelection = false

        locationManager.delegate = self

        ssidCell.textField.delegate = self
        ssidCell.textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        passwordCell.textField.delegate = self
        passwordCell.textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            updateSsid()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNextButton()
        if ssidCell.textField.text?.isEmpty ?? true {
            ssidCell.textField.becomeFirstResponder()
        } else {
            passwordCell.textField.becomeFirstResponder()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        disconnectHotspot()
        super.viewDidDisappear(animated)
    }

    override func didMove(toParent parent: UIViewController?) {
        // This ugly hack is a side effect of the way SwiftUI's UIViewControllerRepresentable works.
        // Ultimately this works poorly enough that we will probably want to re-implement this view in SwiftUI.
        parent?.navigationItem.rightBarButtonItem = navigationItem.rightBarButtonItem
        parent?.navigationItem.title = LocalizedString("setup_wifi_title")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        default:
            break
        }
        fatalError("Unknown section")
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return LocalizedString("setup_wifi_network_details_section_title")
        default:
            break
        }
        fatalError("Unknown section")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return LocalizedString("setup_wifi_network_details_section_footer")
        default:
            break
        }
        fatalError("Unknown section")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                return ssidCell
            case 1:
                return passwordCell
            default:
                break
            }
        default:
            break
        }
        fatalError("Unknown index path")
    }

    func connectToHotspot() {
        ssidCell.textField.resignFirstResponder()
        passwordCell.textField.resignFirstResponder()

        guard let networkDetails = self.networkDetails else {
            print("Incomplete network details")
            return
        }

        let hotspotConfiguration = NEHotspotConfiguration(ssid: hotspotSsid, passphrase: hotspotPassword, isWEP: false)
        hotspotConfiguration.joinOnce = true
        connecting = true
        networkConfigurationManager.apply(hotspotConfiguration) { error in
            if let error = error {
                print("Failed to connect to device hotspot with error \(error).")
                self.present(error: error)
                self.connecting = false
                return
            }
            print("Connected to \(hotspotConfiguration.ssid)!")
            self.configuredHotspotCredentials = hotspotConfiguration
            let rootCerts = String(data: NSDataAsset(name: "TlsCertificates")!.data, encoding: .utf8)!
            self.networkProvisioner.configure(ssid: networkDetails.ssid,
                                              password: networkDetails.password,
                                              certificates: rootCerts) { result in
                switch result {
                case .success:
                    print("Successfully configured network!")
                    DispatchQueue.main.async {
                        self.delegate?.wifiProvisionerViewController(self, didConfigureDevice: self.device)
                    }
                case .failure(let error):
                    print("Failed to configure network with error '\(error)'.")
                    self.present(error: error)
                    self.disconnectHotspot()
                }
                self.connecting = false
            }
        }
    }

    func disconnectHotspot() {
        if let configuredHotspotCredentials = configuredHotspotCredentials {
            networkConfigurationManager.removeConfiguration(forSSID: configuredHotspotCredentials.ssid)
            self.configuredHotspotCredentials = nil
        }
    }

    func updateNextButton() {
        if networkDetails != nil {
            nextButtonItem.isEnabled = true
        } else {
            nextButtonItem.isEnabled = false
        }
    }

    @objc func nextTapped(sender: UIBarButtonItem) {
        connectToHotspot()
    }

    @objc func textChanged(_ sender: UITextField) {
        updateNextButton()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == ssidCell.textField {
            passwordCell.textField.becomeFirstResponder()
        } else if textField == passwordCell.textField {
            if (ssidCell.textField.text?.count ?? 0) > 0 {
                connectToHotspot()
            } else {
                ssidCell.textField.becomeFirstResponder()
            }
        }
        return false
    }

    private func updateSsid() {
        ssidCell.textField.text = GetCurrentSSID()
    }

}

extension WifiProvisionerViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedWhenInUse) {
            updateSsid()
        }
    }

}
