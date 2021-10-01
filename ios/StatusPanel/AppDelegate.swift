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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var background = false
    private var blockUpdates = false
    var window: UIWindow?
    var backgroundFetchCompletionFn : ((UIBackgroundFetchResult) -> Void)?
    var sourceController = DataSourceController()
    var apnsToken: Data?
    var client: Client!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        client = Client(baseUrl: "https://api.statuspanel.io/")

        application.registerForRemoteNotifications()

        window?.tintColor = UIColor(named: "TintColor")
        if let navigationController = window?.rootViewController as? UINavigationController {
            navigationController.navigationBar.prefersLargeTitles = true
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Setting a flag here means we can avoid taking action on temporary
        // interruptions
        background = true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if (background) {
            background = false
            if shouldFetch() {
                update()
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {
        // Process the URL.
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
            let operation = components.path,
            let params = components.queryItems else {
                print("Invalid URL or operation missing")
                return false
            }
        var map: [String : String] = [:]
        for kv in params {
            if let val = kv.value {
                map[kv.name] = val
            }
        }
        // print("op:\(operation) params:\(params)")
        if operation != "r" || map["id"] == nil || map["pk"] == nil {
            print("Unrecognised operation \(operation)")
            return false
        }
        let deviceid = map["id"]!
        let pubkey = map["pk"]!

        // Now try and provision the panel
        if let panelSsid = map["s"] {
            // If the panel is telling us about an SSID, it's in AP mode and needs wifi credentials
            let storyboard = window?.rootViewController?.storyboard
            let navvc = storyboard?.instantiateViewController(identifier: "WifiProvisionerController") as! UINavigationController

            let vc = navvc.topViewController as! WifiProvisionerController
            vc.panelIdentifer = deviceid
            vc.panelPubkey = pubkey
            vc.setHotspotCredentials(ssid: panelSsid, password: pubkey)
            window?.rootViewController?.present(navvc, animated: true, completion: nil)
            return true
        } else {
            addDevice(id: deviceid, pubkey: pubkey)
            return true
        }
    }

    func addDevice(id: String, pubkey: String) {
        let config = Config()
        var devices = config.devices
        devices.append((id, pubkey))
        config.devices = devices
        let alert = UIAlertController(title: "Device added", message: "Device \(id) has been added.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: {
            (action: UIAlertAction) in
            // Sneakily delay fetching data until the user taps ok, to give wifi more time to come back up
            self.blockUpdates = false
            self.update()
        }))
        let root = window?.rootViewController
        let ops = { () -> Void in
            root?.present(alert, animated: true, completion: nil)
        }
        if root?.presentedViewController != nil {
            blockUpdates = true // So the dismissal of the WifiProvisionerController itself doesn't trigger an update
            root?.dismiss(animated: false, completion: ops)
        } else {
            ops()
        }
    }

    func shouldFetch() -> Bool {
        // Don't do extraneous fetches when settings or Wifi Provisioner are showing
        return !blockUpdates && window?.rootViewController?.presentedViewController == nil
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Got APNS token")
        apnsToken = deviceToken
        registerDevice(token: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Aww, no APNS for us. Error: " + error.localizedDescription)
    }


    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("didReceiveRemoteNotification")
        Config().lastBackgroundUpdate = Date()
        backgroundFetchCompletionFn = completionHandler
        if shouldFetch() {
            sourceController.fetch()
        } else {
            print("Not fetching on remote notification")
        }

        // Re-register the device to ensure it doesn't time out on the server.
        if let deviceToken = apnsToken {
            registerDevice(token: deviceToken)
        }

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
        if sourceController.delegate != nil {
            sourceController.fetch()
        }
    }

    func fetchCompleted(hasChanged: Bool) {
        if let fn = backgroundFetchCompletionFn {
            print("Background fetch completed")
            fn(hasChanged ? .newData : .noData)
            backgroundFetchCompletionFn = nil
        }
    }
}
