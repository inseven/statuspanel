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

	@IBOutlet var scrollView: UIScrollView?
	var contentView: UIView?

	var sources = DataSourceController()
	var data = [DataItem]()

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		/*
		let evs = EKEventStore()
		evs.requestAccess(to: EKEntityType.event) { (granted: Bool, err: Error?) in
			if (granted) {
				let calendarSource = CalendarSource(eventStore: evs)
				self.sources.add(dataSource:calendarSource)
			}
			// print("Granted EKEventStore access \(granted) err \(String(describing: err))")
		}

		sources.add(dataSource:TFLDataSource())
		*/
		sources.add(dataSource: DummyDataSource())
		sources.fetchAllData(onCompletion:gotData)
	}

	func gotData(data:[DataItem], done:Bool) {
		self.data = data
		performSelector(onMainThread: #selector(ViewController.drawTheThings), with: nil, waitUntilDone: false)
	}

	@objc func drawTheThings() {
		// Set up contentView and scrollView
		if (self.contentView == nil) {
			self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: 640, height: 384))
		}
		let contentView = self.contentView!
		for subview in contentView.subviews {
			subview.removeFromSuperview()
		}
		if (scrollView != nil) {
			for subview in scrollView!.subviews {
				subview.removeFromSuperview()
			}
		}

		// Construct the contentView's contents
		contentView.backgroundColor = UIColor.lightGray
		let rect = contentView.frame
		let colWidth = rect.width / 2 - 10
		let itemHeight : CGFloat = 40
		var y : CGFloat = 0
		let x : CGFloat = 20
		for item in data {
			print(item)
			let view = UILabel(frame: CGRect(x: x, y: y, width: colWidth, height: itemHeight))
			var text = item.text
			if item.flags.contains(DataItemFlag.warning) {
				// TODO colourise the warning, or use an icon?
				text = "⚠︎ " + text
			}
			view.text = text
			contentView.addSubview(view)
			y = y + itemHeight
		}

		// And render it into an image
		UIGraphicsBeginImageContextWithOptions(rect.size, true, 1.0)
		//let cgcontext = UIGraphicsGetCurrentContext()!
		//cgcontext.setFillColor(UIColor.white.cgColor)
		//cgcontext.fill(rect)
		contentView.drawHierarchy(in: rect, afterScreenUpdates: true)
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		// Finally, do something with that image
		let imgview = UIImageView(image: img)
		scrollView?.contentSize = rect.size
		scrollView?.addSubview(imgview)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}

