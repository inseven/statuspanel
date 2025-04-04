// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

fileprivate func colorForCharacter(_ char: Character) -> UIColor? {
    guard let charName = char.unicodeScalars.first!.properties.name else {
        return nil
    }
    let words = charName.split(separator: " ")
    if words.contains("GREEN") {
        return UIColor.green
    } else if words.contains("RED") {
        return UIColor.red
    } else if words.contains("BLUE") {
        return UIColor.blue
    } else if words.contains("ORANGE") {
        return UIColor.orange
    } else if words.contains("YELLOW") {
        return UIColor.yellow
    }

    return nil
}

class BitmapFontLabel: UILabel {

    var style: BitmapFontCache.Style
    let maxFullSizeLines = Int.max
    var redactMode: RedactMode
    var colorHint = ColorHint.monochrome

    init(frame: CGRect, bitmapFont: Fonts.BitmapInfo, scale: Int = 1, redactMode: RedactMode = .none) {
        self.style = BitmapFontCache.Style(font: bitmapFont, scale: scale, darkMode: false)
        self.redactMode = redactMode
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraits.staticText
        isOpaque = false
    }

    init(frame: CGRect, uiFont: UIFont, redactMode: RedactMode = .none) {
        self.style = BitmapFontCache.Style(uifont: uiFont, darkMode: false)
        self.redactMode = redactMode
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraits.staticText
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var lineHeight: Int {
        return style.font.charh + 1
    }

    var scale: Int {
        return style.scale
    }

    var shrunkLineScale: Int {
        return scale / 2
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

    private func getTextWidth<T>(_ text: T, forScale newScale: Int? = nil) -> Int where T : StringProtocol {
        let targetScale = newScale ?? self.scale
        let style = targetScale == self.scale ? self.style : self.style.withScale(targetScale)
        return BitmapFontCache.shared.getTextWidth(text, forStyle: style)
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

    override var intrinsicContentSize: CGSize {
        sizeThatFits(.zero)
    }

    private func shouldUseDarkMode() -> Bool {
        return (textColor == UIColor.label && traitCollection.userInterfaceStyle == .dark)
        || textColor == UIColor.lightText || textColor == UIColor.white
    }

    private func getImageForChar(ch: Character, forScale: Int? = nil) -> CGImage {
        let scale = forScale ?? self.style.scale
        let style = BitmapFontCache.Style(font: self.style.font, scale: scale, darkMode: self.style.darkMode)
        return BitmapFontCache.shared.getImage(ch, forStyle: style)
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

        // Dark mode may have changed, update style
        self.style = self.style.withDarkMode(shouldUseDarkMode())

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
                let scaledCharHeight = style.font.charh * scale
                let chY = y + line * lineHeight * scale + (scaledCharHeight - chImg.height) / 2
                let rect = CGRect(x: x, y: chY, width: chImg.width, height: chImg.height)
                if redactMode == .redactLines || (redactMode == .redactWords && !ch.isWhitespace) {
                    ctx.fill(rect)
                } else {
                    ctx.saveGState()
                    ctx.clip(to: rect, mask: chImg)
                    if colorHint == .inkyPalette, let charColor = colorForCharacter(ch) {
                        ctx.setFillColor(charColor.cgColor)
                    }
                    ctx.fill(rect)
                    ctx.restoreGState()
                }
                x = x + chImg.width
            }
        }
    }
}
