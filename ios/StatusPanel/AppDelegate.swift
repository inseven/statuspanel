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

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    private var background = false

    var window: UIWindow?
    var viewController: ViewController?
    var config = Config()
    var sourceController: DataSourceController
    var apnsToken: Data?
    var client: Service = Service(baseUrl: "https://api.statuspanel.io/")

    override init() {
        sourceController = DataSourceController(config: config)
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        application.registerForRemoteNotifications()

        do {
            try config.migrate()
        } catch {
            print("Failed to migrate settings with error \(error)")
        }

        let viewController = ViewController(config: config)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        self.viewController = viewController

        window = UIWindow()
        window?.rootViewController = navigationController
        window?.tintColor = UIColor(named: "TintColor")
        window?.makeKeyAndVisible()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Setting a flag here means we can avoid taking action on temporary interruptions.
        background = true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        viewController?.fetch()
    }

    func applicationWillTerminate(_ application: UIApplication) {
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
            addDevice(device)
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            let viewController = WifiProvisionerController(device: device, ssid: ssid)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            window?.rootViewController?.present(navigationController, animated: true)
        }
        return true
    }

    func addDevice(_ device: Device) {
        var devices = config.devices
        devices.append(device)
        config.devices = devices
        let alert = UIAlertController(title: "Device added",
                                      message: "Device \(device.id) has been added.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                      style: .default) { action in
            self.update()
        })
        window?.rootViewController?.present(alert, animated: true)
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
        print("Got APNS token")
        apnsToken = deviceToken
        registerDevice(token: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Aww, no APNS for us. Error: " + error.localizedDescription)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Record the last background update time.
        config.lastBackgroundUpdate = Date()

        // Re-register the device to ensure it doesn't time out on the server.
        if let deviceToken = apnsToken {
            registerDevice(token: deviceToken)
        }

        updateDevices(completion: completionHandler)
    }

    func registerDevice(token: Data) {
        print("Registering device...")
        self.client.registerDevice(token: token) { success, error in
            guard success else {
                print("Failed to register device with error \(String(describing: error)).")
                return
            }
            print("Successfully registered device.")
        }
    }

    func update() {
        viewController?.fetch()
    }

    // Fetch items, generate updates, and upload per-device updates.
    func updateDevices(completion: @escaping (UIBackgroundFetchResult) -> Void = { _ in }) {
        Task {
            do {
                let items = try await AppDelegate.shared.sourceController.fetch()
                let updates = config.devices
                    .map { device in
                        let images = device.renderer.render(data: items, config: config, device: device)
                        let payloads = Panel.encode(images: images, encoding: device.encoding)
                        return Service.Update(device: device, images: payloads)
                    }
                let change = await AppDelegate.shared.client.upload(updates)
                completion(change ? .newData : .noData)
            } catch {
                completion(.failed)
            }
        }
    }

}

extension AppDelegate: WifiProvisionerControllerDelegate {

    func wifiProvisionerController(_ wifiProvisionerController: WifiProvisionerController,
                                   didConfigureDevice device: Device) {
        wifiProvisionerController.navigationController?.dismiss(animated: true) {
            self.addDevice(device)
        }
    }

    func wifiProvisionerControllerDidCancel(_ wifiProvisionerController: WifiProvisionerController) {
        wifiProvisionerController.navigationController?.dismiss(animated: true)
    }

}
