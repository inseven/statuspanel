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
import EventKit
import Sodium

class ViewController: UIViewController, SettingsViewControllerDelegate {
    static let kPanelWidth = 640
    static let kPanelHeight = 384

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var redactButton: UIBarButtonItem!
    private var image: UIImage?
    private var redactedImage: UIImage?
    private var showRedacted = false

    let SettingsButtonTag = 1

    var sourceController: DataSourceController!

    @IBAction func refresh(_ sender: Any) {
        // Wipe all stored hashes to force reupload
        let config = Config()
        for (deviceid, _) in config.devices {
            config.setLastUploadHash(for: deviceid, to: nil)
        }

        sourceController.fetch()
    }

    @IBAction func redact(_ sender: Any) {
        showRedacted = !showRedacted
        updateImageView()
    }

    func updateImageView() {
        if showRedacted {
            imageView.image = redactedImage
            redactButton.title = "🅟"
        } else {
            imageView.image = image
            redactButton.title = "Ⓟ"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        sourceController = appDelegate.sourceController
        sourceController.delegate = self
        if appDelegate.shouldFetch() {
            sourceController.fetch()
        } else {
            print("ViewController.vieWDidLoad: App delegate said not to fetch")
        }
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

    static func getLabel(frame: CGRect, font fontName: String, type: LabelType = .text, redactMode: RedactMode = .none) -> UILabel {
        let font = Config().getFont(named: fontName)
        let size = (type == .header) ? font.headerSize : (type == .subText) ? font.subTextSize : font.textSize
        if let bitmapInfo = font.bitmapInfo {
            if (bitmapInfo.bitmapName == "font6x10" || font.configName == "unifont") && type == .header {
                // Special case this, as neither guicons nor Unifont look good as a header font
                let label = UILabel(frame: frame)
                label.lineBreakMode = .byWordWrapping
                label.font = UIFont(name: "Amiga Forever", size: 24)
                return label
            }
            return BitmapFontLabel(frame: frame, font: font, scale: size, redactMode: redactMode)
        } else {
            let label = UILabel(frame: frame)
            label.lineBreakMode = .byWordWrapping
            if let uifont = UIFont(name: font.uifontName!, size: CGFloat(size)) {
                label.font = uifont
            } else {
                print("No UIFont found for \(font.uifontName!)!")
                for family in UIFont.familyNames {
                    for fontName in UIFont.fontNames(forFamilyName: family) {
                        print("Candidate: \(fontName)")
                    }
                }
            }
            return label
        }
    }

    func renderAndUpload(data: [DataItemBase], completion: @escaping (Bool) -> Void) {
        let image = renderToImage(data: data, shouldRedact: false)
        let privacyImage = (Config().privacyMode == .customImage) ?
            ViewController.cropCustomRedactImageToPanelSize() : renderToImage(data: data, shouldRedact: true)

        let payloads = makeRlePayloadsFor(images: [image, privacyImage])
        self.image = payloads[0].1
        self.redactedImage = payloads[1].1

        updateImageView()
        let imageData = payloads.map { $0.0 }
        print("Uploading new images")
        uploadImages(imageData, completion: { (anythingChanged: Bool) in
            print("Changes: \(anythingChanged)")
            completion(anythingChanged)
        })
    }

    func makeRlePayloadsFor(images: [UIImage]) -> [(Data, UIImage)] {
        var result: [(Data, UIImage)] = []
        for (i, image) in images.enumerated() {
            let (rawdata, panelImage) = imgToARGBData(image)
            let panelData = ARGBtoPanel(rawdata)
            let rleData = rleEncode(panelData)
            do {
                let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                print("GOT DIR! " + dir.absoluteString)
                let imgdata = panelImage.pngData()
                let name = "img_\(i)"
                try imgdata?.write(to: dir.appendingPathComponent(name + ".png"))
                try rawdata.write(to: dir.appendingPathComponent(name + ".raw"))
                try panelData.write(to: dir.appendingPathComponent(name + "_panel"))
                try rleData.write(to: dir.appendingPathComponent(name + "_panel_rle"))
            } catch {
                print("meh")
            }
            result.append((rleData, panelImage))
        }
        return result
    }

    class func blankPanelImage() -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: kPanelWidth, height: kPanelHeight), format: fmt)
        let uiImage = renderer.image {(uictx: UIGraphicsImageRendererContext) in }
        return uiImage
    }

    class func cropCustomRedactImageToPanelSize() -> UIImage {
        var path: URL?
        do {
            let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            path = dir.appendingPathComponent("customPrivacyImage.png")
        } catch {
            print("meh")
            return blankPanelImage()
        }
        guard let source = UIImage(contentsOfFile: path!.path), let cgImage = source.cgImage else {
            return blankPanelImage()
        }
        let rect = CGRect(center: source.center, size: CGSize(width: kPanelWidth, height: kPanelHeight))
        if let cgCrop = cgImage.cropping(to: rect) {
            return UIImage(cgImage: cgCrop)
        } else {
            return blankPanelImage()
        }
    }

    enum DividerStyle {
        case vertical(originY: CGFloat)
        case horizontal(originY: CGFloat)
    }

    func renderToImage(data: [DataItemBase], shouldRedact: Bool) -> UIImage {
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: ViewController.kPanelWidth, height: ViewController.kPanelHeight))
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
        var divider: DividerStyle? = twoCols ? .vertical(originY: 0) : nil
        let redactMode: RedactMode = (shouldRedact ? (config.privacyMode == .redactWords ? .redactWords : .redactLines) : .none)
        for (i, item) in data.enumerated() {
            let flags = item.getFlags()
            let firstItemHeader = i == 0 && flags.contains(.header)
            let w = firstItemHeader ? rect.width : colWidth
            let frame = CGRect(x: x, y: y, width: w, height: 0)
            let view = UIView(frame: frame)
            var prefix = item.getPrefix()
            let numPrefixLines = prefix.split(separator: "\n").count
            var textFrame = CGRect(origin: CGPoint.zero, size: frame.size)
            var itemHeight: CGFloat = 0
            if prefix != "" {
                let prefixLabel = ViewController.getLabel(frame: textFrame, font: config.font, redactMode: redactMode)
                prefixLabel.textColor = foregroundColor
                prefixLabel.numberOfLines = numPrefixLines
                prefixLabel.text = prefix + " "
                prefixLabel.sizeToFit()
                let prefixWidth = prefixLabel.frame.width
                if prefixWidth < frame.width / 2 {
                    prefix = ""
                    view.addSubview(prefixLabel)
                    textFrame = textFrame.divided(atDistance: prefixWidth, from: .minXEdge).remainder
                    itemHeight = prefixLabel.frame.height
                } else {
                    // Label too long, treat as single text entity (leave 'prefix' set)
                    prefix = prefix + " "
                }
            }
            let label = ViewController.getLabel(frame: textFrame, font: config.font,
                                                type: firstItemHeader ? .header : .text,
                                                redactMode: redactMode)
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
            label.numberOfLines = config.maxLines
            label.lineBreakMode = .byTruncatingTail
            label.text = text
            label.sizeToFit()
            itemHeight = max(itemHeight, label.bounds.height)
            label.frame = CGRect(x: label.frame.minX, y: label.frame.minY, width: textFrame.width, height: label.frame.height)
            view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: itemHeight))
            view.addSubview(label)
            if let subText = item.getSubText() {
                let subLabel = ViewController.getLabel(frame: textFrame, font: config.font, type: .subText, redactMode: redactMode)
                subLabel.textColor = foregroundColor
                subLabel.numberOfLines = config.maxLines
                subLabel.text = subText
                subLabel.sizeToFit()
                subLabel.frame = CGRect(x: textFrame.minX, y: view.bounds.maxY + 1, width: textFrame.width, height: subLabel.frame.height)
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
                divider = .horizontal(originY: y)
                let c = view.center
                view.center = CGPoint(x: c.x, y: c.y + itemGap)
                y += itemGap
            }
            contentView.addSubview(view)

            // Update the divider to account for the height of the header.
            if firstItemHeader {
                divider = .vertical(originY: sz.height + itemGap)
            }

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

        // Draw the dividing line.
        if let divider = divider {

            context.setStrokeColor(foregroundColor.cgColor)
            context.beginPath()

            switch divider {
            case .vertical(let originX):
                context.move(to: CGPoint(x: midx, y: originX))
                context.addLine(to: CGPoint(x: midx, y: rect.height - 20))
            case .horizontal(let originY):
                context.move(to: CGPoint(x: x, y: originY))
                context.addLine(to: CGPoint(x: rect.width - x, y: originY))
            }

            context.drawPath(using: .stroke)
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        // I don't think this can realistically ever be nil
        return img!
    }

    func uploadImages(_ images: [Data], completion: @escaping (Bool) -> Void) {
        var devices = Config().devices
        if devices.count == 0 {
            print("No keys configured, not uploading")
            completion(false)
            return
        }

        var nextUpload : (Bool) -> Void = { (b: Bool) -> Void in }
        var anythingUploaded = false
        nextUpload = { (lastUploadDidUpload: Bool) in
            if lastUploadDidUpload {
                anythingUploaded = true
            }
            if devices.count == 0 {
                completion(anythingUploaded)
            } else {
                let (id, pubkey) = devices.remove(at: 0)
                if pubkey.isEmpty {
                    // Empty keys are used for debugging the UI, and shouldn't cause an upload
                    nextUpload(false)
                    return
                }
                self.uploadImages(images, deviceid: id, publickey: pubkey, completion: nextUpload)
            }
        }
        nextUpload(false)
    }

    func uploadImages(_ images: [Data], deviceid: String, publickey: String, completion: @escaping (Bool) -> Void) {
        let sodium = Sodium()
        guard let key = sodium.utils.base642bin(publickey, variant: .ORIGINAL) else {
            print("Failed to decode key from publickey userdefault!")
            completion(false)
            return
        }

        // We can't just hash the resulting encryptedData because libsodium ensures it is different every time even
        // for identical input data (which normally is a good thing!) so we have to construct a unencrypted blob just
        // for the purposes of calculating the hash.
        let hash = sodium.utils.bin2base64(sodium.genericHash.hash(message: Array(makeMultipartUpload(parts: images)))!, variant: .ORIGINAL)!
        if hash == Config().getLastUploadHash(for: deviceid) {
            print("Data for \(deviceid) is the same as before, not uploading")
            completion(false)
            return
        }

        var encryptedParts: [Data] = []
        for image in images {
            let encryptedDataBytes = sodium.box.seal(message: Array(image), recipientPublicKey: key)
            if encryptedDataBytes == nil {
                print("Failed to seal box")
                completion(false)
                return
            }
            encryptedParts.append(Data(encryptedDataBytes!))
        }
        let encryptedData = makeMultipartUpload(parts: encryptedParts)
        let path = "https://api.statuspanel.io/api/v2/\(deviceid)"
        guard let url = URL(string: path) else {
            print("Unable to create URL")
            completion(false)
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
            if let error = error {
                print(error)
            } else {
                Config().setLastUploadHash(for: deviceid, to: hash)
            }
            completion(true)
        })
        task.resume()
    }

    func makeMultipartUpload(parts: [Data]) -> Data {
        let wakeTime = Int(Config.getLocalWakeTime() / 60)
        // Header format is as below. Any fields beyond length can be omitted
        // providing the length is set appropriately.
        // FF 00 - indicating header present
        // NN    - Length of header
        // TT TT - wakeup time
        // CC    - count of images (index immediately follows header)
        var data = Data([0xFF, 0x00, 0x06, UInt8(wakeTime >> 8), UInt8(wakeTime & 0xFF), UInt8(parts.count)])
        // I'm sure there's a way to do this with UnsafeRawPointers or something, but eh
        let u32le = { (val: Int) -> Data in
            let u32 = UInt32(val)
            return Data([UInt8(u32 & 0xFF), UInt8((u32 & 0xFF00) >> 8), UInt8((u32 & 0xFF0000) >> 16), UInt8(u32 >> 24)])
        }
        var idx = data.count + 4 * parts.count
        for part in parts {
            data += u32le(idx)
            idx += part.count
        }
        for part in parts {
            data += part
        }
        return data
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
        BitmapFontCache.shared.emptyCache()
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
