//
//  AppDelegate.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var sourceController = DataSourceController()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        sourceController.add(dataSource:TFLDataSource())
        sourceController.add(dataSource:NationalRailDataSource())
        sourceController.add(dataSource:CalendarSource())
        sourceController.add(dataSource:CalendarSource(forDayOffset: 1, header: "Tomorrow:"))
//        sourceController.add(dataSource: DummyDataSource())
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        sourceController.fetch()
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any] = [:] ) -> Bool {
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

        let ud = UserDefaults.standard
        ud.set(map["id"], forKey: "deviceid")
        ud.set(map["pk"], forKey: "publickey")

        return true
    }
}
