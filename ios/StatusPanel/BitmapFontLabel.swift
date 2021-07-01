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
import CoreImage

class ImagesDict {
    private var value: [Character : CGImage] = [:]
    func get(_ ch: Character) -> CGImage? {
        return value[ch]
    }
    func set(_ ch: Character, _ img: CGImage) {
        value[ch] = img
    }
}

enum RedactMode {
    case none, redactLines, redactWords
}

class BitmapFontLabel: UILabel {
    private static var globalCache: [String : ImagesDict] = [:]
    let fontName: String
    let image: CIImage
    let charw: Int
    let charh: Int
    let scale: Int
    private var invertedForDarkMode: CIImage?
    let maxFullSizeLines = Int.max
    var redactMode: RedactMode

    init(frame: CGRect, fontNamed: String, scale: Int = 1, redactMode: RedactMode = .none) {
        self.fontName = fontNamed
        let font = UIImage(named: "fonts/" + self.fontName)!
        image = CIImage(image: font)!
        let w = image.extent.width
        let h = image.extent.height
        charw = (Int)(w / 8)
        charh = (Int)(h / 12)
        self.scale = scale
        self.redactMode = redactMode
        super.init(frame: frame)
        assert((CGFloat)(charw * 8) == w && (CGFloat)(charh * 12) == h,
               "Image size \(w)x\(h) must be a multiple of 8 wide and 12 high")
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraits.staticText
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var lineHeight: Int {
        get {
            return charh + 1
        }
    }

    var shrunkLineScale: Int {
        get {
            return scale / 2
        }
    }

    private func flow(text: String?, width: CGFloat, scale: Int? = nil) -> [String] {
        guard let text = text else {
            return []
        }
        let maxWidth = Int(width)
        var lines: [String] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let splits = StringUtils.splitLine(line, maxWidth: maxWidth, widthFn: { getTextWidth($0, forScale: scale) })
            lines.append(contentsOf: splits)
        }
        if numberOfLines > 0 && lines.count > numberOfLines {
            lines = Array(lines[0..<numberOfLines])
            var lastLine = lines.last!
            while (lastLine.count > 0 && getTextWidth(lastLine + "…", forScale: scale) > maxWidth) {
                lastLine = String(lastLine.prefix(lastLine.count - 1))
            }
            lines[lines.count - 1] = lastLine + "…"
        }
        return lines
    }

    private func getTextWidth<T>(_ text: T, forScale scale: Int? = nil) -> Int where T : StringProtocol {
        var result = 0
        for ch in text {
            result = result + getCharWidth(ch, forScale: scale)
        }
        return result
    }

    private func getCharWidth(_ char: Character, forScale scale: Int? = nil) -> Int {
        if char.isASCII {
            return charw * (scale ?? self.scale)
        } else {
            return getImageForChar(ch: char, forScale: scale).width
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if numberOfLines == 1 {
            // Then grow width instead. I think this is pretty much how UILabel
            // does it normally.
            return CGSize(width: getTextWidth(text ?? ""), height: lineHeight * scale)
        }
        let lines = flow(text: self.text, width: size.width)
        var longest = 0
        for line in lines {
            longest = max(longest, getTextWidth(line))
        }
        var h = lines.count * lineHeight * scale
        if lines.count > maxFullSizeLines {
            let overflowText = lines[maxFullSizeLines...].joined(separator: " ")
            let nshrunk = flow(text: overflowText, width: size.width, scale: shrunkLineScale).count
            h = (maxFullSizeLines * lineHeight * scale) + (nshrunk * lineHeight * shrunkLineScale)
        }
        return CGSize(width: longest, height: h)
    }

    private func shouldUseDarkMode() -> Bool {
        return (textColor == UIColor.label && traitCollection.userInterfaceStyle == .dark)
        || textColor == UIColor.lightText || textColor == UIColor.white
    }

    private static func getImageCache(fontName: String, scale: Int, darkMode: Bool) -> ImagesDict {
        let theme = (darkMode ? "dark" : "light")
        let key = "\(fontName)_\(scale)_\(theme)"
        if let result = BitmapFontLabel.globalCache[key] {
            return result
        }
        let result = ImagesDict()
        BitmapFontLabel.globalCache[key] = result
        return result
    }

    // Must be an easier way than this...
    // Note this effectively also does a flip, thanks to rendering a CGImage in a context
    private func scaleUp(image ciImage: CIImage, factor: Int) -> CGImage {
        let unscaledCGImage = CIContext().createCGImage(ciImage, from: ciImage.extent)!
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let scaleFactor = CGFloat(factor)
        let unscaledWidth = ciImage.extent.width
        let unscaledHeight = ciImage.extent.height
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: unscaledWidth * scaleFactor, height: unscaledHeight * scaleFactor), format: fmt)
        let uiImage = renderer.image { (uictx: UIGraphicsImageRendererContext) in
            let ctx = uictx.cgContext
            ctx.setAllowsAntialiasing(false)
            ctx.interpolationQuality = .none
            ctx.scaleBy(x: scaleFactor, y: scaleFactor)
            ctx.draw(unscaledCGImage, in: CGRect(x: 0, y: 0, width: unscaledWidth, height: unscaledHeight))
        }
        return uiImage.cgImage!
    }

    private func makeReplacementImage(for charName: String, scale: Int) -> CGImage {
        let textWidth = getTextWidth(charName, forScale: 1)
        let h = charh * scale
        let w = textWidth + 8
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt)
        let uiImage = renderer.image { (uictx: UIGraphicsImageRendererContext) in
            let ctx = uictx.cgContext
            ctx.setAllowsAntialiasing(false)
            ctx.interpolationQuality = .none
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.translateBy(x: 0, y: CGFloat(-h))
            var x = 4
            let y = (h - charh) / 2
            ctx.setLineWidth(CGFloat(scale))
            let col: CGFloat = shouldUseDarkMode() ? 1 : 0
            ctx.setStrokeColor(red: col, green: col, blue: col, alpha: 1)
            ctx.stroke(CGRect(x: 0, y: 0, width: w, height: h))
            for ch in charName {
                ctx.draw(getImageForChar(ch: ch, forScale: 1), in: CGRect(x: x, y: y, width: charw, height: charh))
                x += charw
            }
        }
        return uiImage.cgImage!
    }

    private func getImageForChar(ch: Character, forScale: Int? = nil) -> CGImage {
        let darkMode = shouldUseDarkMode()
        let scale = forScale ?? self.scale
        let imgCache = BitmapFontLabel.getImageCache(fontName: fontName, scale: scale, darkMode: darkMode)
        var img = imgCache.get(ch)
        if let img = img {
            return img
        }

        if ch.isASCII && ch.asciiValue! >= 0x20 && ch.asciiValue! <= 0x7F {
            // Get from main image
            if darkMode && invertedForDarkMode == nil {
                invertedForDarkMode = self.image.applyingFilter("CIColorInvert")
                // Wow that is much simpler than the old code:
                // let filter = CIFilter(name: "CIColorInvert")!
                // filter.setValue(CIImage(image: self.image), forKey: kCIInputImageKey)
                // let invertedCgImage = CIContext().createCGImage(filter.outputImage!, from: filter.outputImage!.extent)!
            }
            let char = Int(ch.asciiValue!) - 0x20
            let x = char & 0x7
            // y is counting from the bottom because of stupid coordinate space rubbish, and there's 12 rows
            let y = 12 - (char >> 3) - 1
            let imageToUse = darkMode ? invertedForDarkMode! : self.image
            let cropped = imageToUse.cropped(to: CGRect(x: x * charw, y: y * charh, width: charw, height: charh))
            img = scaleUp(image: cropped, factor: scale)
        } else {
            // See if we have an individual image for it
            let charName = ch.unicodeScalars.map({ String(format:"U+%04X", $0.value) }).joined(separator: "_")
            var scaleForImage = 1
            var uiImage = UIImage(named: "fonts/\(fontName)/\(charName)@\(scale)")
            if uiImage == nil {
                // Try an unscaled one we can scale up
                uiImage = UIImage(named: "fonts/\(fontName)/\(charName)")
                scaleForImage = scale
            }
            // If there's still no joy, try just the first code point, scaled then unscaled
            let firstCodepointName = String(format:"U+%X", ch.unicodeScalars.first!.value)
            if uiImage == nil {
                uiImage = UIImage(named: "fonts/\(fontName)/\(firstCodepointName)@\(scale)")
                scaleForImage = 1
            }
            if uiImage == nil {
                uiImage = UIImage(named: "fonts/\(fontName)/\(firstCodepointName)")
                scaleForImage = scale
            }

            if let uiImage = uiImage {
                var ciImage = CIImage(image: uiImage)!
                if darkMode {
                    ciImage = ciImage.applyingFilter("CIColorInvert")
                }
                img = scaleUp(image: ciImage, factor: scaleForImage)
            } else {
                print("No font data for character \(charName)")
                if scale > 1 {
                    img = makeReplacementImage(for: charName, scale: scale)
                } else {
                    img = getImageForChar(ch: "\u{7F}", forScale:scale)
                }
            }
        }

        // Update image cache
        imgCache.set(ch, img!)
        return img!
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        if let col = self.backgroundColor {
            ctx.setFillColor(col.cgColor)
            ctx.fill(rect)
        }
        ctx.setFillColor(textColor.cgColor)

        let lines = flow(text: self.text, width: self.bounds.width)
        let numFullsizeLines = min(lines.count, maxFullSizeLines)
        drawLines(Array(lines.prefix(numFullsizeLines)), at: 0, forScale: scale, in: ctx)
        if numFullsizeLines < lines.count {
            let pos = numFullsizeLines * lineHeight * scale
            let overflowText = lines[maxFullSizeLines...].joined(separator: " ")
            let shrunkLines = flow(text: overflowText, width: self.bounds.width, scale: shrunkLineScale)
            drawLines(shrunkLines, at:pos, forScale: shrunkLineScale, in: ctx)
        }

        if redactMode != .none {
            ctx.drawPath(using: .fill)
        }
    }

    private func drawLines(_ lines: [String], at y: Int, forScale scale: Int, in ctx: CGContext) {
        for (line, text) in lines.enumerated() {
            var x = 0
            for ch in text {
                let chImg = getImageForChar(ch: ch, forScale: scale)
                let rect = CGRect(x: x, y: y + line * lineHeight * scale, width: chImg.width, height: charh * scale)
                if redactMode == .redactLines || (redactMode == .redactWords && !ch.isWhitespace) {
                    ctx.addRect(rect)
                } else {
                    ctx.draw(chImg, in: rect)
                }
                x = x + chImg.width
            }
        }
    }

    static func clearImageCache() {
        print("Resetting img cache")
        globalCache = [:]
    }
}