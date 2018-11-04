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
        sourceController.add(dataSource: NationalRailDataSource())
        sourceController.add(dataSource:CalendarSource())
        sourceController.add(dataSource:CalendarSource(forDayOffset: 1, header: "Tomorrow:"))
//        sourceController.add(dataSource: DummyDataSource())
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        sourceController.fetch()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
