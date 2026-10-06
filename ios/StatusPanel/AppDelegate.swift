// Copyright (c) 2018-2026 Jason Morley, Tom Sutcliffe
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

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let dataSourceController: DataSourceController
    let applicationModel: ApplicationModel
    var apnsToken: Data?

    override init() {
        let config = Config.shared
        dataSourceController = DataSourceController(config: config)
        applicationModel = ApplicationModel(dataSourceController: dataSourceController, config: config)
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {

        guard let operation = ExternalOperation(url: url) else {
            qrcodeParseFailed(url)
            return false
        }

        switch operation {
        case .registerDevice(let device):
            applicationModel.addDevice(device)
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            let viewController = WifiProvisionerViewController(device: device, ssid: ssid)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            window?.rootViewController?.present(navigationController, animated: true)
        }
        return true
    }

    func qrcodeParseFailed(_ url: URL) {
        let alert = UIAlertController(title: "Device add failed",
                                      message: "Unable to parse URL \(url)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: .default))
        window?.rootViewController?.present(alert, animated: true)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        apnsToken = deviceToken
        applicationModel.registerDevice(token: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.applicationModel.error = error
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Record the last background update time.
        Config.shared.lastBackgroundUpdate = Date()

        // Re-register the device to ensure it doesn't time out on the server.
        if let deviceToken = apnsToken {
            applicationModel.registerDevice(token: deviceToken)
        }

        applicationModel.updateDevices(completion: completionHandler)
    }

}

extension AppDelegate: WifiProvisionerViewControllerDelegate {

    func wifiProvisionerViewController(_ wifiProvisionerViewController: WifiProvisionerViewController,
                                   didConfigureDevice device: Device) {
        wifiProvisionerViewController.navigationController?.dismiss(animated: true) {
            self.applicationModel.addDevice(device)
        }
    }

    func wifiProvisionerViewControllerDidCancel(_ wifiProvisionerViewController: WifiProvisionerViewController) {
        wifiProvisionerViewController.navigationController?.dismiss(animated: true)
    }

}
