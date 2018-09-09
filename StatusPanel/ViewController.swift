//
//  ViewController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import UIKit
import EventKit

class ViewController: UIViewController {

	var sources = DataSourceController()
	var data = [DataItem]()

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		let evs = EKEventStore()
		evs.requestAccess(to: EKEntityType.event) { (granted: Bool, err: Error?) in
			if (granted) {
				let calendarSource = CalendarSource(eventStore: evs)
				self.sources.add(dataSource:calendarSource)
			}
			// print("Granted EKEventStore access \(granted) err \(String(describing: err))")
		}

		sources.add(dataSource:TFLDataSource())
		sources.fetchAllData(onCompletion:gotData)
	}

	func gotData(data:[DataItem], done:Bool) {

	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}

