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
    var sourceController: DataSourceController!

	override func viewDidLoad() {
		super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        sourceController = appDelegate.sourceController
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sourceController.fetchAllData { (data, done) in
            DispatchQueue.main.async {
                self.drawTheThings(data: data)
            }
        }
    }

    func drawTheThings(data: [DataItem]) {
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
		var x : CGFloat = 10
		var y : CGFloat = 0
		let colWidth = rect.width / 2 - x * 2
		let itemGap : CGFloat = 10
		var colStart = y
		for item in data {
			print(item)
			let w = item.flags.contains(.header) ? rect.width : colWidth
			let view = UILabel(frame: CGRect(x: x, y: y, width: w, height: 0))
			view.numberOfLines = 0
			view.lineBreakMode = .byWordWrapping
			if item.flags.contains(.warning) {
				// Icons don't render well on the panel, use a coloured background instead
				view.backgroundColor = UIColor.yellow
			}
			let fname = "Amiga Forever"
			if item.flags.contains(.header) {
				view.font = UIFont(name: fname, size: 24)
			} else {
				view.font = UIFont(name: fname, size: 16)
			}
			view.text = item.text
			view.sizeToFit()
			view.frame = CGRect(x: view.frame.minX, y: view.frame.minY, width: w, height: view.frame.height)
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
		let context = UIGraphicsGetCurrentContext()!
		context.setShouldAntialias(false)
		context.setShouldSubpixelQuantizeFonts(false)
		context.interpolationQuality = .none

		contentView.drawHierarchy(in: rect, afterScreenUpdates: true)

		// Draw some other UI furniture
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

		let rawdata = imgToARGBData(image)
		let panelData = ARGBtoPanel(rawdata)
		let rleData = rleEncode(panelData)

		// Finally, do something with that image
		do {
			let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			print("GOT DIR! " + dir.absoluteString)
			let imgdata = UIImagePNGRepresentation(image)
			try imgdata?.write(to: dir.appendingPathComponent("img.png"))
			try rawdata.write(to: dir.appendingPathComponent("img.raw"))
			try panelData.write(to: dir.appendingPathComponent("img_panel"))
			try rleData.write(to: dir.appendingPathComponent("img_panel_rle"))
			uploadData(rleData)
		} catch {
			print("meh")
		}
		let imgview = UIImageView(image: image)
		scrollView?.contentSize = rect.size
		scrollView?.addSubview(imgview)
	}

    // TODO: Completion block
    func uploadData(_ data: Data) {

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

        let fname = "img_panel_rle"
        let mimetype = "application/octet-stream"

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

	func imgToARGBData(_ image:UIImage) -> Data {
		// From https://stackoverflow.com/questions/448125/how-to-get-pixel-data-from-a-uiimage-cocoa-touch-or-cgimage-core-graphics

		var result = Data()

		// First get the image into your data buffer
		guard let cgImage = image.cgImage else {
			print("CGContext creation failed")
			return result
		}

		let width = cgImage.width
		let height = cgImage.height
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let rawdata = calloc(height*width*4, MemoryLayout<CUnsignedChar>.size)
		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		let bitsPerComponent = 8
		let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

		guard let context = CGContext(data: rawdata, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
			print("CGContext creation failed")
			return result
		}

		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		// Now your rawData contains the image data in the RGBA8888 pixel format.
		var byteIndex = 0 //bytesPerRow * y + bytesPerPixel * x

		for _ in 0..<width*height {
			//let alpha = CGFloat(rawdata!.load(fromByteOffset: byteIndex + 3, as: UInt8.self)) / 255.0
			let red = rawdata!.load(fromByteOffset: byteIndex, as: UInt8.self)
			let green = rawdata!.load(fromByteOffset: byteIndex + 1, as: UInt8.self)
			let blue = rawdata!.load(fromByteOffset: byteIndex + 2, as: UInt8.self)
			byteIndex += bytesPerPixel
			result.append(contentsOf: [0xFF, red, green, blue])
		}
		free(rawdata)
		return result
	}

	func ARGBtoPanel(_ data: Data) -> Data {
		var result = Data()
		var i = 0
		while i < data.count {
			let hex = (UInt32(data[i+1]) << 16) + (UInt32(data[i+2]) << 8) + UInt32(data[i+3])
			if hex == 0 {
				result.append(0) // Black
			} else if hex == 0xFFFF00 || hex == 0xFF0000 {
				result.append(4) // Colour
			} else {
				result.append(3)
			}
			i += 4
		}
		return result
	}

	func rleEncode(_ data: Data) -> Data {
		var result = Data()
		var len : UInt8 = 0
		var current : UInt8 = 0
		func flush() {
			if len == 0 {
				// Nothing to do
			} else if len == 1 && current != 255 {
				result.append(current)
			} else {
				result.append(contentsOf: [255, len, current])
			}
			len = 0
			current = 0
		}

		for byte in data {
			if len == 0 {
				current = byte
				len = 1
			} else if byte == current && len < 255 {
				len += 1
			} else {
				flush()
				current = byte
				len = 1
			}
		}
		flush()
		return result
	}
}

