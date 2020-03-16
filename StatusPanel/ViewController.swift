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

class ViewController: UIViewController, SettingsViewControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    let SettingsButtonTag = 1

    var sourceController: DataSourceController!
    var prevImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        sourceController = appDelegate.sourceController
        sourceController.delegate = self
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "settings" {
            guard
                let navigationController = segue.destination as? UINavigationController,
                let settingsViewController = navigationController.viewControllers[0] as? SettingsViewController else {
                    return
            }
            settingsViewController.delegate = self
        }
    }

    func didDismiss(settingsViewController: SettingsViewController) {
        sourceController.fetch()
    }

    enum LabelType {
        case text, header, subText
    }

    static func getLabel(frame: CGRect, font fontName: String, type: LabelType = .text) -> UILabel {
        if fontName == "font6x10_2" && type != .header {
            return BitmapFontLabel(frame: frame, fontNamed: "font6x10", scale: type == .text ? 2 : 1)
        }

        // Otherwise it's a UIFont-based label
        var font: UIFont?
        if fontName == "advocut" {
            font = UIFont(name: "AdvoCut", size:
                type == .header ? 37 : type == .text ? 27 : 13)
        } else if fontName == "silkscreen" {
            font = UIFont(name: "Silkscreen", size:
                type == .header ? 32 : type == .text ? 17 : 11)
        } else {
            // amiga4ever
            font = UIFont(name: "Amiga Forever", size:
                type == .header ? 24 : type == .text ? 16 : 8)
        }

        let label = UILabel(frame: frame)
        label.lineBreakMode = .byWordWrapping
        label.font = font
        return label
    }

    func renderAndUpload(data: [DataItemBase], completion: @escaping (Bool) -> Void) {
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 640, height: 384))
        contentView.contentScaleFactor = 1.0

        // Construct the contentView's contents. For now just make labels and flow them into 2 columns
        // TODO move this to UICollectionView?
        let darkMode = shouldBeDark()
        contentView.backgroundColor = darkMode ? UIColor.black : UIColor.white
        let foregroundColor = darkMode ? UIColor.white : UIColor.black
        let config = Config()
        let twoCols = config.displayTwoColumns
        let rect = contentView.frame
        let maxy = rect.height - 10 // Leave space for status line
        let midx = rect.width / 2
        var x : CGFloat = 5
        var y : CGFloat = 0
        let colWidth = twoCols ? (rect.width / 2 - x * 2) : rect.width - x
        let itemGap : CGFloat = 10
        var colStart = y
        var col = 1
        var verticalBreak: CGFloat = 0
        for (i, item) in data.enumerated() {
            // print(item)
            let flags = item.getFlags()
            let firstItemHeader = i == 0 && flags.contains(.header)
            let w = firstItemHeader ? rect.width : colWidth
            let frame = CGRect(x: x, y: y, width: w, height: 0)
            let view = UIView(frame: frame)
            var prefix = item.getPrefix()
            var textFrame = CGRect(origin: CGPoint.zero, size: frame.size)
            if prefix != "" {
                let prefixLabel = ViewController.getLabel(frame: textFrame, font: config.font)
                prefixLabel.textColor = foregroundColor
                prefixLabel.numberOfLines = 1
                prefixLabel.text = prefix + " "
                prefixLabel.sizeToFit()
                let prefixWidth = prefixLabel.frame.width
                if prefixWidth < frame.width / 2 {
                    prefix = ""
                    view.addSubview(prefixLabel)
                    textFrame = textFrame.divided(atDistance: prefixWidth, from: .minXEdge).remainder
                } else {
                    // Label too long, treat as single text entity (leave 'prefix' set)
                    prefix = prefix + " "
                }
            }
            let label = ViewController.getLabel(frame: textFrame, font: config.font,
                                               header: firstItemHeader)
            label.numberOfLines = 1 // Temporarily while we're using it in checkFit

            let text = prefix + item.getText(checkFit: { (string: String) -> Bool in
                label.text = prefix + string
                let size = label.sizeThatFits(textFrame.size)
                return size.width <= textFrame.width
            })
            label.textColor = foregroundColor
            if flags.contains(.warning) {
                // Icons don't render well on the panel, use a coloured background instead
                label.backgroundColor = UIColor.yellow
                label.textColor = UIColor.black
            }
            label.numberOfLines = 0
            label.text = text
            label.sizeToFit()
            label.frame = CGRect(x: label.frame.minX, y: label.frame.minY, width: textFrame.width, height: label.frame.height)
            view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: label.bounds.height))
            view.addSubview(label)
            if let subText = item.getSubText() {
                let subLabel = ViewController.getLabel(frame: textFrame, font: config.font, type: .subText)
                subLabel.textColor = foregroundColor
                subLabel.numberOfLines = 0
                subLabel.text = subText
                subLabel.sizeToFit()
                subLabel.frame = CGRect(x: textFrame.minX, y: label.frame.maxY + 1, width: textFrame.width, height: subLabel.frame.height)
                view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: subLabel.frame.maxY))
                view.addSubview(subLabel)
            }
            let sz = view.frame
            // Enough space for this item?
            let itemIsColBreak = i != 0 && flags.contains(.header)
            if (col == 1 && twoCols && (sz.height > maxy - y || itemIsColBreak)) {
                // overflow to 2nd column
                col += 1
                x += midx + 5
                y = colStart
                view.frame = CGRect(x: x, y: y, width: sz.width, height: sz.height)
            } else if (!twoCols && itemIsColBreak) {
                // Leave some extra space and mark where to draw a line
                verticalBreak = y
                let c = view.center
                view.center = CGPoint(x: c.x, y: c.y + itemGap)
                y += itemGap
            }
            contentView.addSubview(view)
            y = y + sz.height + itemGap
            if i == 0 && flags.contains(.header) {
                colStart = y
            }
        }

        // And render it into an image
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 1.0)
        let context = UIGraphicsGetCurrentContext()!
        context.setShouldAntialias(false)
        context.setShouldSubpixelQuantizeFonts(false)
        context.setShouldSubpixelPositionFonts(false)
        context.setShouldSmoothFonts(false)
        context.interpolationQuality = .none

        // layer.render() works when the device is locked, whereas drawHierarchy() doesn't
        contentView.layer.render(in: context)

        // Draw the dividing line
        context.setStrokeColor(foregroundColor.cgColor)
        if twoCols {
            context.beginPath()
            context.move(to: CGPoint(x: midx, y: 40))
            context.addLine(to: CGPoint(x: midx, y: rect.height - 20))
            context.drawPath(using: .stroke)
        } else if verticalBreak != 0 {
            context.beginPath()
            context.move(to: CGPoint(x: x, y: verticalBreak))
            context.addLine(to: CGPoint(x: rect.width - x, y: verticalBreak))
            context.drawPath(using: .stroke)
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image = img else {
            print("Unable to generate image")
            return
        }

        let (rawdata, panelImage) = imgToARGBData(image)
        let changes = !panelImage.isEqual(prevImage)
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
            let imgdata = UIImagePNGRepresentation(panelImage)
            self.imageView.image = panelImage
            try imgdata?.write(to: dir.appendingPathComponent("img.png"))
            try rawdata.write(to: dir.appendingPathComponent("img.raw"))
            try panelData.write(to: dir.appendingPathComponent("img_panel"))
            try rleData.write(to: dir.appendingPathComponent("img_panel_rle"))
            uploadData(rleData, completion: {
                print("Update: changes = \(changes)")
                self.prevImage = panelImage
                completion(changes)
            })
        } catch {
            print("meh")
        }
    }

    func uploadData(_ data: Data, completion: @escaping () -> Void) {
        var devices = Config().devices
        if devices.count == 0 {
            print("No keys configured, not uploading")
            completion()
            return
        }
        var nextUpload : () -> Void = {}
        nextUpload = {
            if devices.count == 0 {
                completion()
            } else {
                let (firstDevice, firstKey) = devices.remove(at: 0)
                if firstKey.isEmpty {
                    // Empty keys are used for debugging the UI, and shouldn't cause an upload
                    nextUpload()
                    return
                }
                self.uploadData(data, deviceid: firstDevice, publickey: firstKey, completion: nextUpload)
            }
        }
        nextUpload()
    }

    func uploadData(_ data: Data, deviceid: String, publickey: String, completion: @escaping () -> Void) {
        let sodium = Sodium()
        guard let key = sodium.utils.base642bin(publickey, variant: .ORIGINAL) else {
            print("Failed to decode key from publickey userdefault!")
            completion()
            return
        }
        let encryptedDataBytes = sodium.box.seal(message: Array(data), recipientPublicKey: key)
        if encryptedDataBytes == nil {
            print("Failed to seal box")
            completion()
            return
        }
        let encryptedData = Data(encryptedDataBytes!)

        let path = "https://statuspanel.io/api/v2/\(deviceid)"
        guard let url = URL(string: path) else {
            print("Unable to create URL")
            completion()
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
            completion()
        })
        task.resume()
    }

    func flattenColours(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let col = UIColor.init(red: CGFloat(red) / 256, green: CGFloat(green) / 256, blue: CGFloat(blue) / 256, alpha: 0)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        col.getHue(&hue, saturation: &sat, brightness: &brightness, alpha: &alpha)

        // Numbers are from 30 seconds fiddling with a HSB colour wheel
        let isYellow = hue >= 0.11 && hue <= 0.21 && sat >= 0.2 && brightness > 0.8

        if isYellow {
            return (0xFF, 0xFF, 0x00) // Yellow
        } else if brightness < 0.75 {
            return (0, 0, 0) // Black
        } else {
            return (0xFF, 0xFF, 0xFF) // White
        }
    }

    func imgToARGBData(_ image:UIImage) -> (Data, UIImage) {
        // From https://stackoverflow.com/questions/448125/how-to-get-pixel-data-from-a-uiimage-cocoa-touch-or-cgimage-core-graphics

        var result = Data()

        // First get the image into your data buffer
        guard let cgImage = image.cgImage else {
            print("CGImage creation failed")
            return (result, image)
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawdata = calloc(height*width*4, MemoryLayout<CUnsignedChar>.size)!
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: rawdata, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("CGContext creation failed")
            return (result, image)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Now your rawData contains the image data in the RGBA8888 pixel format.
        var byteIndex = 0 //bytesPerRow * y + bytesPerPixel * x

        for _ in 0..<width*height {
            let red = rawdata.load(fromByteOffset: byteIndex, as: UInt8.self)
            let green = rawdata.load(fromByteOffset: byteIndex + 1, as: UInt8.self)
            let blue = rawdata.load(fromByteOffset: byteIndex + 2, as: UInt8.self)

            let (newr, newg, newb) = flattenColours(red, green, blue)
            rawdata.storeBytes(of: newr, toByteOffset: byteIndex, as: UInt8.self)
            rawdata.storeBytes(of: newg, toByteOffset: byteIndex + 1, as: UInt8.self)
            rawdata.storeBytes(of: newb, toByteOffset: byteIndex + 2, as: UInt8.self)
            byteIndex += bytesPerPixel
            result.append(contentsOf: [0xFF, newr, newg, newb])
        }
        let resultImage = UIImage(cgImage: context.makeImage()!)
        free(rawdata)
        return (result, resultImage)
    }

    func ARGBtoPanel(_ data: Data) -> Data {
        let Black: UInt8 = 0, Colored: UInt8 = 1, White: UInt8 = 2
        var result = Data()
        var i = 0
        var byte: UInt8 = 0
        while i < data.count {
            let red = data[i+1]
            let green = data[i+2]
            let blue = data[i+3]

            var val : UInt8 = 0
            if red == 0xFF && green == 0xFF && blue == 0 {
                val = Colored
            } else if red == 0 && green == 0 && blue == 0 {
                val = Black
            } else if red == 0xFF && green == 0xFF && blue == 0xFF {
                val = White
            } else {
                print(String(format: "Unexpected colour value! 0x%02X%02X%02X", red, green, blue))
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

    private func shouldBeDark() -> Bool {
        switch Config().darkMode {
        case .off:
            return false
        case .on:
            return true
        case .system:
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        BitmapFontLabel.clearImageCache()
    }

}

extension ViewController: DataSourceControllerDelegate {
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItemBase]) {
        self.renderAndUpload(data: data, completion: { (changes: Bool) -> Void in
                DispatchQueue.main.async {
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    appDelegate.fetchCompleted(hasChanged: changes)
                }
            })
    }
}
