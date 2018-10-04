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

		/*
		sources.add(dataSource:TFLDataSource())
		sources.add(dataSource:CalendarSource())
		*/
        sources.add(dataSource:CalendarSource())
//        sources.add(dataSource: DummyDataSource())

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

		// Construct the contentView's contents. For now just make labels and flow them into 2 columns
		// TODO move this to UICollectionView?
		contentView.backgroundColor = UIColor.white
		let rect = contentView.frame
		let midx = rect.width / 2
		var x : CGFloat = 20
		var y : CGFloat = 0
		let colWidth = rect.width / 2 - x
		let itemGap : CGFloat = 10
		var colStart = y
		for item in data {
			print(item)
			let w = item.flags.contains(.header) ? rect.width : colWidth
			let view = UILabel(frame: CGRect(x: x, y: y, width: w, height: 0))
			view.numberOfLines = 0
			var text = item.text
			if item.flags.contains(.warning) {
				// TODO colourise the warning, or use an icon?
				text = "⚠︎ " + text
			}
			if item.flags.contains(.header) {
				view.font = UIFont.boldSystemFont(ofSize: 24)
			}
			view.text = text
			view.sizeToFit()
			let sz = view.frame
			// Enough space for this item?
			if (sz.height > rect.height - y) {
				// overflow to 2nd column
				x += midx
				y = colStart
				view.frame = CGRect(x: x, y: y, width: sz.width, height: sz.height)
			}
			contentView.addSubview(view)
			y = y + sz.height + itemGap
			if item.flags.contains(.header) {
				colStart = y
			}
		}

		// And render it into an image
		UIGraphicsBeginImageContextWithOptions(rect.size, true, 1.0)
		contentView.drawHierarchy(in: rect, afterScreenUpdates: true)

		// Draw some other UI furniture
		let context = UIGraphicsGetCurrentContext()!
		context.setStrokeColor(UIColor.black.cgColor)
		context.beginPath()
		context.move(to: CGPoint(x: midx, y: 40))
		context.addLine(to: CGPoint(x: midx, y: rect.height - 20))
		context.drawPath(using: .stroke)
		context.setStrokeColor(UIColor.lightGray.cgColor)
		context.stroke(rect, width: 1)

		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

        guard let image = img else {
            print("Unable to generate image")
            return
        }

		// Finally, do something with that image
		let imgview = UIImageView(image: image)
		scrollView?.contentSize = rect.size
		scrollView?.addSubview(imgview)

        uploadImage(image)
	}

    func uploadImage(_ image: UIImage) {

        guard let data = UIImagePNGRepresentation(image) else {
            print("Unable to get PNG representation")
            return
        }

        let path = "https://calendar-image-server.herokuapp.com/api/v1"

        guard let url = URL(string: path) else {
            print("Unable to create URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "---------------------------14737809831466499882746641449"
        let contentType = "multipart/form-data; boundary=\(boundary)"

        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Disposition:form-data; name=\"test\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        body.append("hi\r\n".data(using: String.Encoding.utf8)!)

        let fname = "test.png"
        let mimetype = "image/png"

        body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Disposition:form-data; name=\"file\"; filename=\"\(fname)\"\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: String.Encoding.utf8)!)
        body.append(data)
        body.append("\r\n".data(using: String.Encoding.utf8)!)
        body.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)

        request.httpBody = body
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            print(response ?? "")
            print(error ?? "")
        })
        task.resume()

    }

}

