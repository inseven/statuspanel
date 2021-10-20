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

import UIKit
import CoreLocation
import NetworkExtension
import Network

// Thanks https://stackoverflow.com/questions/56583650/cncopycurrentnetworkinfo-with-ios-13
func GetCurrentSSID() -> String? {
    let interfaces = CNCopySupportedInterfaces() as? [String]
    let interface = interfaces?.compactMap { GetInterfaceInfo($0) }.first
    return interface
}

func GetInterfaceInfo(_ interface: String) -> String? {
    guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject],
          let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
    else {
        return nil
    }
    return ssid
}

class WifiProvisionerController: UITableViewController, UITextFieldDelegate {

    struct NetworkDetails {
        var ssid: String
        var password: String
    }

    private lazy var ssidCell: TextFieldTableViewCell = {
        let cell = TextFieldTableViewCell()
        cell.textField.placeholder = "Name"
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        return cell
    }()

    private lazy var passwordCell: TextFieldTableViewCell = {
        let cell = TextFieldTableViewCell()
        cell.textField.placeholder = "Password"
        cell.textField.isSecureTextEntry = true
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        return cell
    }()

    private lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel,
                               target: self,
                               action: #selector(cancelTapped(sender:)))
    }()

    private lazy var nextButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTapped(sender:)))
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

        navigationItem.leftBarButtonItem = cancelButtonItem
        navigationItem.rightBarButtonItem = nextButtonItem
        title = "Setup WiFi"

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
        if AppDelegate.shared.shouldFetch() {
            AppDelegate.shared.update()
        } else {
            print("Not fetching from WifiProvisionerController.viewDidDisappear")
        }
        super.viewDidDisappear(animated)
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
            return "Network Details"
        default:
            break
        }
        fatalError("Unknown section")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Your StatusPanel will use this WiFI network to check for updates."
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
            self.networkProvisioner.configure(ssid: networkDetails.ssid,
                                              password: networkDetails.password) { result in
                switch result {
                case .success:
                    print("Successfully configured network!")
                    AppDelegate.shared.addDevice(self.device)  // addDevice will dismiss us, so we're done!
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

    @objc func cancelTapped(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
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

extension WifiProvisionerController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedWhenInUse) {
            updateSsid()
        }
    }

}
