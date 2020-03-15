//
//  BitmapFontLabel.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 07/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

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

class BitmapFontLabel: UILabel {
    private static var globalCache: [String : ImagesDict] = [:]
    let fontName: String
    let image: CIImage
    let charw: Int
    let charh: Int
    let scale: Int
    private var invertedForDarkMode: CIImage?
    let maxFullSizeLines = Int.max
    private var charWidths: [Character: Int] = [:]

    init(frame: CGRect, fontNamed: String, scale: Int = 1) {
        self.fontName = fontNamed
        let font = UIImage(named: self.fontName)!
        // Flip the image here because of annoying coordinate space rubbish
        let flip = CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0, y: -font.size.height)
        image = CIImage(image: font)!.transformed(by: flip)
        let w = image.extent.width
        let h = image.extent.height
        charw = (Int)(w / 8)
        charh = (Int)(h / 12)
        self.scale = scale
        super.init(frame: frame)
        assert((CGFloat)(charw * 8) == w && (CGFloat)(charh * 12) == h,
               "Image size \(w)x\(h) must be a multiple of 8 wide and 12 high")
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraitStaticText
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
        let scale = scale ?? self.scale
        let maxWidth = Int(width) / scale
        var lines: [String] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let splits = StringUtils.splitLine(String(line), maxWidth: maxWidth, widthFn: { getTextWidth($0) })
            lines.append(contentsOf: splits)
        }
        return lines
    }

    private func getTextWidth<T>(_ text: T) -> Int where T : StringProtocol {
        var result = 0
        for ch in text {
            result = result + getCharWidth(ch)
        }
        return result
    }

    private func getCharWidth(_ char: Character) -> Int {
        if char.isASCII {
            return charw
        } else if let w = charWidths[char] {
            return w
        } else {
            return getImageForChar(ch: char).width // This will populate charWidths for next time
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if numberOfLines == 1 {
            // Then grow width instead. I think this is pretty much how UILabel
            // does it normally.
            return CGSize(width: getTextWidth(text ?? "") * scale, height: lineHeight * scale)
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
        return CGSize(width: longest * scale, height: h)
    }

    private func shouldUseDarkMode() -> Bool {
        return (textColor == UIColor.label && traitCollection.userInterfaceStyle == .dark)
        || textColor == UIColor.lightText || textColor == UIColor.white
    }

    private static func getImageCache(fontName: String, darkMode: Bool) -> ImagesDict {
        let theme = (darkMode ? "dark" : "light")
        let key = "\(fontName)_\(theme)"
        if let result = BitmapFontLabel.globalCache[key] {
            return result
        }
        let result = ImagesDict()
        BitmapFontLabel.globalCache[key] = result
        return result
    }

    private func getImageForChar(ch: Character) -> CGImage {
        let darkMode = shouldUseDarkMode()
        let imgCache = BitmapFontLabel.getImageCache(fontName: fontName, darkMode: darkMode)
        var img = imgCache.get(ch)
        if let img = img {
            if charWidths[ch] == nil {
                charWidths[ch] = img.width
            }
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
            let y = char >> 3
            let imageToUse = darkMode ? invertedForDarkMode! : self.image
            img = CIContext().createCGImage(imageToUse, from: CGRect(x: x * charw, y: y * charh, width: charw, height: charh))!
        } else {
            // See if we have an individual image for it
            let charName = ch.unicodeScalars.compactMap({ String(format:"U+%X", $0.value) }).joined(separator: "_")
            let charImgName = "\(fontName)_\(charName)"
            if let uiImage = UIImage(named: charImgName) {
                let flip = CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0, y: -uiImage.size.height)
                var ciImage = CIImage(image: uiImage)!.transformed(by: flip)
                if darkMode {
                    ciImage = ciImage.applyingFilter("CIColorInvert")
                }
                img = CIContext().createCGImage(ciImage, from: ciImage.extent)!
            } else {
                print("No font data for character \(charName)")
                img = getImageForChar(ch: "\u{7F}")
            }
        }

        // Update image cache
        imgCache.set(ch, img!)
        charWidths[ch] = img!.width
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

        let lines = flow(text: self.text, width: self.bounds.width)
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

        let numFullsizeLines = min(lines.count, maxFullSizeLines)
        drawLines(Array(lines.prefix(numFullsizeLines)), at: 0, in: ctx)
        if numFullsizeLines < lines.count {
            let ratio = CGFloat(shrunkLineScale) / CGFloat(scale) // eg 1/2
            ctx.scaleBy(x: ratio, y: ratio)
            let pos = (numFullsizeLines * lineHeight * scale) / shrunkLineScale
            let overflowText = lines[maxFullSizeLines...].joined(separator: " ")
            let shrunkLines = flow(text: overflowText, width: self.bounds.width, scale: shrunkLineScale)
            drawLines(shrunkLines, at:pos, in: ctx)
        }
    }

    private func drawLines(_ lines: [String], at y: Int, in ctx: CGContext) {
        for (line, text) in lines.enumerated() {
            var x = 0
            for ch in text {
                let chImg = getImageForChar(ch: ch)
                ctx.draw(chImg, in: CGRect(x: x, y: y + line * lineHeight, width: chImg.width, height: charh))
                x = x + chImg.width
            }
        }
    }

    static func clearImageCache() {
        print("Resetting img cache")
        globalCache = [:]
    }
}
