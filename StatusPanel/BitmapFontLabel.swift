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
    let image: UIImage
    let charw: Int
    let charh: Int
    let scale: Int
    var invertedForDarkMode: UIImage?

    convenience init(frame: CGRect, fontNamed: String, scale: Int = 1) {
        self.init(frame: frame, font: UIImage(named: fontNamed)!, scale: scale)
    }

    init(frame: CGRect, font: UIImage, scale: Int = 1) {
        image = font
        let w = image.size.width
        let h = image.size.height
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

    private func flow(width: CGFloat) -> [String] {
        guard let text = self.text else {
            return []
        }
        let maxChars = Int(width) / (charw * scale)
        var lines: [String] = []
        for line in text.split(separator: "\n") {
            let splits = StringUtils.splitLine(String(line), maxChars: maxChars)
            lines.append(contentsOf: splits)
        }
        return lines
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let lines = flow(width: size.width)
        var longest = 0
        for line in lines {
            longest = max(longest, line.count)
        }
        return CGSize(width: longest * charw * scale, height: lines.count * (charh + 1) * scale)
    }

    private func getImageForChar(ch: Character) -> CGImage {
        let darkMode = (self.textColor == UIColor.label && traitCollection.userInterfaceStyle == .dark)
            || self.textColor == UIColor.lightText || self.textColor == UIColor.white
        if darkMode && invertedForDarkMode == nil {
            let filter = CIFilter(name: "CIColorInvert")!
            filter.setValue(CIImage(image: self.image), forKey: kCIInputImageKey)
            let invertedCgImage = CIContext().createCGImage(filter.outputImage!, from: filter.outputImage!.extent)!
            invertedForDarkMode = UIImage(cgImage: invertedCgImage)
        }

        var char: Int = 0x7F
        if ch.isASCII && ch.asciiValue! >= 0x20 && ch.asciiValue! <= 0x7F {
            char = Int(ch.asciiValue!)
        }
        char = char - 0x20
        let x = char & 0x7
        let y = char >> 3
        let imageToUse = darkMode ? invertedForDarkMode! : image
        return (imageToUse.cgImage?.cropping(to: CGRect(x: x * charw, y: y * charh, width: charw, height: charh)))!
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        let lines = flow(width: bounds.width)
        let h = lines.count * (charh + 1) * scale
        // Contexts are draw-from-bottom by default, hence the -1.0
        ctx.scaleBy(x: 1.0 * CGFloat(scale), y: -1.0 * CGFloat(scale))
        ctx.translateBy(x: 0, y: CGFloat(-h))

        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        if let col = self.backgroundColor {
            ctx.setFillColor(col.cgColor)
            ctx.fill(rect)
        }

        for (line, text) in lines.enumerated() {
            for (i, ch) in text.enumerated() {
                let chImg = getImageForChar(ch: ch)
                ctx.draw(chImg, in: CGRect(x: i * charw, y: h - ((line+1) * (charh+1)), width: charw, height: charh))
            }
        }
    }
}
