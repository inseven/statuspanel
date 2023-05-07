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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    @MainActor static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?
    var config = Config()
    var dataSourceController: DataSourceController
    var applicationModel: ApplicationModel
    var apnsToken: Data?
    var client: Service = Service(baseUrl: "https://api.statuspanel.io/")

    override init() {
        dataSourceController = DataSourceController(config: config)
        applicationModel = ApplicationModel(dataSourceController: dataSourceController, config: config)
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

        window = UIWindow()
        window?.rootViewController = UIHostingController(rootView: ContentView(applicationModel: applicationModel,
                                                                               config: config,
                                                                               dataSourceController: dataSourceController))
        window?.tintColor = UIColor(named: "TintColor")
        window?.makeKeyAndVisible()

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
            addDevice(device)
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            let viewController = WifiProvisionerViewController(device: device, ssid: ssid)
            viewController.delegate = self
            let navigationController = UINavigationController(rootViewController: viewController)
            window?.rootViewController?.present(navigationController, animated: true)
        }
        return true
    }

    func configureDataSourceInstance<T: DataSourceSettings>(type: DataSourceType,
                                                            settings: T) throws -> DataSourceInstance.Details {
        let instanceId = UUID()
        let details = DataSourceInstance.Details(id: instanceId, type: type)
        try config.save(settings: settings, instanceId: instanceId)
        return details
    }

    func configureDataSourceInstances(_ dataSourceSettings: [AnyDataSourceSettings]) throws -> [DataSourceInstance.Details] {
        var result: [DataSourceInstance.Details] = []
        for settings in dataSourceSettings {
            let instanceId = UUID()
            let details = DataSourceInstance.Details(id: instanceId, type: settings.dataSourceType)
            try config.save(settings: settings, instanceId: instanceId)
            result.append(details)
        }
        return result
    }

    func addDevice(_ device: Device) {

        // Set up the initial data sources if necessary.
        // This is a little inelegant as it presumes we'll only need to request access to EKEventStore and hard-codes
        // that request here--a better approach would be to introduce a an asynchronous DataSource API that allows
        // each source to request access to the stores it requires.
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: EKEntityType.event) { granted, error in
            DispatchQueue.main.async {

                do {
                    let calendars = eventStore.allCalendars().map { $0.calendarIdentifier }
                    var settings = device.defaultSettings()
                    let dataSourceSettings = device.defaultDataSourceSettings(calendars: calendars)
                    settings.dataSources = try self.configureDataSourceInstances(dataSourceSettings)
                    try self.config.save(settings: settings, deviceId: device.id)
                } catch {
                    self.window?.rootViewController?.present(error: error)
                    return
                }
                self.config.devices.insert(device)

                let alert = UIAlertController(title: "Device added",
                                              message: "Device \(device.id) has been added.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"),
                                              style: .default))
                self.window?.rootViewController?.present(alert, animated: true)
            }
        }
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

    // Fetch items, generate updates, and upload per-device updates.
    // Counter-intuitively, this is now called from the `ApplicationModel` instance as application lifecycle is now
    // split between the model and delegate.
    // Ultimately, this functionality should probably be pushed into `ApplicationModel`.
    func updateDevices(completion: @escaping (UIBackgroundFetchResult) -> Void = { _ in }) {
        Task {
            do {
                let updates = try await config.devices
                    .asyncMap { device in
                        print("Generating update for \(device.id)...")
                        let settings = try config.settings(forDevice: device.id)
                        let items = try await AppDelegate.shared.dataSourceController.fetch(details: settings.dataSources)
                        let images = device.renderer.render(data: items, config: config, device: device, settings: settings)
                        let payloads = Panel.encode(images: images, encoding: device.encoding)
                        return Service.Update(device: device, settings: settings, images: payloads)
                    }
                let change = await AppDelegate.shared.client.upload(updates)
                completion(change ? .newData : .noData)
            } catch {
                completion(.failed)
            }
        }
    }

}

extension AppDelegate: WifiProvisionerViewControllerDelegate {

    func wifiProvisionerViewController(_ wifiProvisionerViewController: WifiProvisionerViewController,
                                   didConfigureDevice device: Device) {
        wifiProvisionerViewController.navigationController?.dismiss(animated: true) {
            self.addDevice(device)
        }
    }

    func wifiProvisionerViewControllerDidCancel(_ wifiProvisionerViewController: WifiProvisionerViewController) {
        wifiProvisionerViewController.navigationController?.dismiss(animated: true)
    }

}
