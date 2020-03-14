//
//  BitmapFontLabel.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 07/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import UIKit
import CoreImage

class BitmapFontLabel: UILabel {
    let image: CIImage
    let charw: Int
    let charh: Int
    let scale: Int
    var invertedForDarkMode: CIImage?
    let maxFullSizeLines = Int.max

    convenience init(frame: CGRect, fontNamed: String, scale: Int = 1) {
        self.init(frame: frame, font: UIImage(named: fontNamed)!, scale: scale)
    }

    init(frame: CGRect, font: UIImage, scale: Int = 1) {
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
        let maxChars = Int(width) / (charw * scale)
        var lines: [String] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let splits = StringUtils.splitLine(String(line), maxChars: maxChars)
            lines.append(contentsOf: splits)
        }
        return lines
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if numberOfLines == 1 {
            // Then grow width instead. I think this is pretty much how UILabel
            // does it normally.
            return CGSize(width: (text?.count ?? 0) * charw * scale , height: lineHeight * scale)
        }
        let lines = flow(text: self.text, width: size.width)
        var longest = 0
        for line in lines {
            longest = max(longest, line.count)
        }
        var h = lines.count * lineHeight * scale
        if lines.count > maxFullSizeLines {
            let overflowText = lines[maxFullSizeLines...].joined(separator: " ")
            let nshrunk = flow(text: overflowText, width: size.width, scale: shrunkLineScale).count
            h = (maxFullSizeLines * lineHeight * scale) + (nshrunk * lineHeight * shrunkLineScale)
        }
        return CGSize(width: longest * charw * scale, height: h)
    }

    private func getImageForChar(ch: Character) -> CGImage {
        let darkMode = (self.textColor == UIColor.label && traitCollection.userInterfaceStyle == .dark)
            || self.textColor == UIColor.lightText || self.textColor == UIColor.white
        if darkMode && invertedForDarkMode == nil {
            invertedForDarkMode = self.image.applyingFilter("CIColorInvert")
            // Wow that is much simpler than the old code:
            // let filter = CIFilter(name: "CIColorInvert")!
            // filter.setValue(CIImage(image: self.image), forKey: kCIInputImageKey)
            // let invertedCgImage = CIContext().createCGImage(filter.outputImage!, from: filter.outputImage!.extent)!
        }

        var char: Int
        if ch.isASCII && ch.asciiValue! >= 0x20 && ch.asciiValue! <= 0x7F {
            char = Int(ch.asciiValue!)
        } else {
            char = 0x7F
        }
        char = char - 0x20
        let x = char & 0x7
        let y = char >> 3
        let imageToUse = darkMode ? invertedForDarkMode! : self.image
        return CIContext().createCGImage(imageToUse, from: CGRect(x: x * charw, y: y * charh, width: charw, height: charh))!
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
            print(shrunkLines)
            drawLines(shrunkLines, at:pos, in: ctx)
        }
    }

    func drawLines(_ lines: [String], at y: Int, in ctx: CGContext ) {
        for (line, text) in lines.enumerated() {
            for (i, ch) in text.enumerated() {
                let chImg = getImageForChar(ch: ch)
                ctx.draw(chImg, in: CGRect(x: i * charw, y: y + line * lineHeight, width: charw, height: charh))
            }
        }
    }
}
