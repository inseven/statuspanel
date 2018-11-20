//
//  ViewController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import UIKit
import EventKit
import Sodium

class ViewController: UIViewController {

    @IBOutlet var scrollView: UIScrollView?
    var contentView: UIView?
    var sourceController: DataSourceController!
    var prevItems: [DataItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        sourceController = appDelegate.sourceController
        sourceController.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        let maxy = rect.height - 10 // Leave space for status line
        let midx = rect.width / 2
        var x : CGFloat = 10
        var y : CGFloat = 0
        let colWidth = rect.width / 2 - x * 2
        let itemGap : CGFloat = 10
        var colStart = y
        var col = 1
        for (i, item) in data.enumerated() {
            // print(item)
            let firstItemHeader = i == 0 && item.flags.contains(.header)
            let w = firstItemHeader ? rect.width : colWidth
            let view = UILabel(frame: CGRect(x: x, y: y, width: w, height: 0))
            view.numberOfLines = 0
            view.lineBreakMode = .byWordWrapping
            if item.flags.contains(.warning) {
                // Icons don't render well on the panel, use a coloured background instead
                view.backgroundColor = UIColor.yellow
            }

            let fname = "Amiga Forever"
            if firstItemHeader {
                view.font = UIFont(name: fname, size: 24)
            } else {
                view.font = UIFont(name: fname, size: 16)
            }
            view.text = item.text
            view.sizeToFit()
            view.frame = CGRect(x: view.frame.minX, y: view.frame.minY, width: w, height: view.frame.height)
            let sz = view.frame
            // Enough space for this item?
            if (col == 1 && (sz.height > maxy - y || (i != 0 && item.flags.contains(.header)))) {
                // overflow to 2nd column
                col += 1
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

        //DEBUG
        //for i in stride(from: 0, to: rect.size.width, by: 30) {
        //    context.setStrokeColor(UIColor.yellow.cgColor)
        //    context.beginPath()
        //    context.move(to: CGPoint(x:i, y:0))
        //    context.addLine(to: CGPoint(x:i, y:rect.size.height - 1))
        //    context.drawPath(using: .stroke)
        //}

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image = img else {
            print("Unable to generate image")
            return
        }

        let rawdata = imgToARGBData(image)
        let panelData = ARGBtoPanel(rawdata)
        // Header format is as below. Any fields beyond length can be omitted
        // providing the length is set appropriately.
        // FF 00 - indicating header present
        // NN    - Length of header
        // TT TT - wakeup time
        let wakeTime = Int(Config.getLocalWakeTime() / 60)
        let header = Data([0xFF, 0x00, 0x05, UInt8(wakeTime >> 8), UInt8(wakeTime & 0xFF)])
        let rleData = header + rleEncode(panelData)

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
        let ud = UserDefaults.standard
        guard let deviceid = ud.value(forKey: "deviceid"),
              let publickey : String = ud.value(forKey: "publickey") as? String else {
            print("Keys not configured yet, not uploading")
            return
        }
        let sodium = Sodium()
        guard let key = sodium.utils.base642bin(publickey, variant: .ORIGINAL) else {
            print("Failed to decode key from publickey userdefault!")
            return
        }
        let encryptedDataBytes = sodium.box.seal(message: Array(data), recipientPublicKey: key)
        if encryptedDataBytes == nil {
            print("Failed to seal box")
            return
        }
        let encryptedData = Data(encryptedDataBytes!)

        let path = "https://statuspanel.io/api/v2/\(deviceid)"
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
        body.append(encryptedData)
        body.append("\r\n".data(using: String.Encoding.utf8)!)
        body.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)

        request.httpBody = body
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            // print(response ?? "")
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
        let Black: UInt8 = 0, Colored: UInt8 = 1, White: UInt8 = 2
        var result = Data()
        var i = 0
        var byte: UInt8 = 0
        while i < data.count {
            let hex = (UInt32(data[i+1]) << 16) + (UInt32(data[i+2]) << 8) + UInt32(data[i+3])
            var val : UInt8 = 0
            if hex == 0 {
                val = Black
            } else if hex == 0xFFFF00 || hex == 0xFF0000 {
                val = Colored
            } else {
                val = White
            }
            // For pixels A, B, C, D the packed 2bpp layout is:
            // 76543210
            // DDCCBBAA
            let bitshift = ((i >> 2) & 3) * 2
            byte |= val << bitshift
            if bitshift == 6 {
                result.append(byte)
                byte = 0
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
                // For a length below 3, the encoding is longer so don't bother
                if len > 3 || current == 255 {
                    result.append(contentsOf: [255, len, current])
                } else {
                    for _ in 1...len {
                        result.append(current)
                    }
                }
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

extension ViewController: DataSourceControllerDelegate {
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItem]) {

        let changes = (prevItems != data)
        print("Update: changes = \(changes)")
        prevItems = data

        DispatchQueue.main.async {
            if changes {
                self.drawTheThings(data: data)
            }
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.fetchCompleted(hasChanged: changes)
        }
    }
}
