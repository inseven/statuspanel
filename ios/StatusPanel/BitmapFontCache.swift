// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

class BitmapFontCache {

    // Contains all the info required to render and cache a character: the font bitmap to use, the scale, and the dark mode
    struct Style {
        let font: Fonts.BitmapInfo
        let scale: Int
        let darkMode: Bool
        init(font: Fonts.BitmapInfo, scale: Int, darkMode: Bool) {
            self.font = font
            self.scale = scale
            self.darkMode = darkMode
        }
        func toString() -> String {
            let theme = (darkMode ? "dark" : "light")
            return "\(font.bitmapName)_\(scale)_\(theme)"
        }

        var scaledHeight : Int {
            return self.font.charh * self.scale
        }
        var scaledWidth : Int {
            return self.font.charw * self.scale
        }
        var scaledAscent : Int {
            return self.font.ascent * self.scale
        }
        var scaledDescent : Int {
            return self.font.descent * self.scale
        }
        var scaledCapHeight : Int {
            return self.font.capHeight * self.scale
        }
    }

    private class ImagesDict {
        private let style: Style
        var font: Fonts.BitmapInfo { return style.font }
        var fontName: String { return font.bitmapName }
        private let image: CIImage
        let imagew: Int
        let imageh: Int
        var charw: Int { return font.charw }
        var charh: Int { return font.charh }
        var charsPerRow: Int { return imagew / charw }
        var numRows: Int { return imageh / charh }
        private var charMap: [Character : CGImage] = [:]

        init(forKey key: Style) {
            self.style = key
            let image = CIImage(image: UIImage(named: "fonts/" + key.font.bitmapName)!)!
            if key.darkMode {
                self.image = image.applyingFilter("CIColorInvert")
            } else {
                self.image = image
            }
            imagew = Int(image.extent.width)
            imageh = Int(image.extent.height)
            assert(imagew % charsPerRow == 0 && imageh % numRows == 0,
                   "Image size \(imagew)x\(imageh) must be a multiple of the char width \(charw) and the char height \(charh)")
        }

        static func stripChar(_ char: Character) -> Character {
            // First try and remove any modifiers from the character which we can't represent and don't care about.
            // We deliberately don't just chop the char off at the first code point, because I want to be able to
            // identify sequences we don't currently handle. Also things like flag sequences would be mangled if we
            // did that.
            var scalars = char.unicodeScalars
            while scalars.count > 1 {
                if scalars.lastInRange(.VariationSelectorStart, .VariationSelectorEnd) {
                    // Variation selector, particularly U+FE0E and U+FE0F for text-only style and emoji-style.
                    scalars.removeLast()
                } else if scalars.lastInRange(.SkinToneStart, .SkinToneEnd) {
                    // Skin tone modifier (EMOJI MODIFIER FITZPATRICK TYPE)
                    scalars.removeLast()
                } else if scalars.count > 2 && scalars.scalarAt(index: -2, equals: .ZeroWidthJoiner) &&
                            (scalars.lastIs(.FemaleSign) || scalars.lastIs(.MaleSign)) {
                    // Zero-width joiner plus female/male sign
                    scalars.removeLast(2)
                } else {
                    break
                }
            }
            return Character(String(scalars))
        }

        func getImageForChar(_ char: Character) -> CGImage? {
            let strippedChar = Self.stripChar(char)
            if let img = charMap[strippedChar] {
                return img
            }
            if let img = createImageForChar(strippedChar) {
                charMap[strippedChar] = img
                return img
            }
            return nil
        }

        func setImageForChar(_ ch: Character, image: CGImage) {
            charMap[Self.stripChar(ch)] = image
        }

        func charInImage(_ char: Character) -> Bool {
            let strippedChar = Self.stripChar(char)
            if strippedChar.unicodeScalars.count != 1 {
                return false
            }
            let scalarValue = strippedChar.unicodeScalars.first!.value
            let maxValue = font.startIndex.value + UInt32(self.charsPerRow * self.numRows)
            return scalarValue >= font.startIndex.value && scalarValue < maxValue
        }

        // Must be an easier way than this...
        // Note this effectively also does a flip, thanks to rendering a CGImage in an unflipped context
        static func scaleUp(image unscaledCGImage: CGImage, factor: Int) -> CGImage {
            let scaleFactor = CGFloat(factor)
            let unscaledWidth = CGFloat(unscaledCGImage.width)
            let unscaledHeight = CGFloat(unscaledCGImage.height)
            let scaledSize = CGSize(width: unscaledWidth * scaleFactor, height: unscaledHeight * scaleFactor)
            let img = CGImage.New(scaledSize, flipped: false) { ctx in
                ctx.scaleBy(x: scaleFactor, y: scaleFactor)
                ctx.draw(unscaledCGImage, in: CGRect(x: 0, y: 0, width: unscaledWidth, height: unscaledHeight))
            }
            return img
        }

        static func getCharName(_ ch: Character) -> String {
            return ch.unicodeScalars.map({ String(format:"U+%04X", $0.value) }).joined(separator: "_")
        }

        // Note, ch must have been already stripped of extraneous modifiers
        func createImageForChar(_ ch: Character) -> CGImage? {
            if charInImage(ch) {
                // Get from main image
                let charIdx = ch.unicodeScalars.first!.value - font.startIndex.value
                let x = Int(charIdx % UInt32(self.charsPerRow))
                // y is counting from the bottom because of stupid coordinate space rubbish
                let y = self.numRows - Int(charIdx / UInt32(self.charsPerRow)) - 1
                let cropped = self.image.cropped(to: CGRect(x: x * charw, y: y * charh, width: charw, height: charh))
                var cgImage = CIContext().createCGImage(cropped, from: cropped.extent)!
                if let minCharWidth = font.minWidth {
                    // See if we need to trim any whitespace from the right-hand side of the image
                    var w = charw
                    let pixelData = cgImage.dataProvider!.data!
                    let ptr: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                    func columnIsClear(_ x:Int) -> Bool {
                        for y in 0 ..< charh {
                            let offset = y * cgImage.bytesPerRow + x * (cgImage.bitsPerPixel / 8)
                            // let r = ptr[offset]
                            // let g = ptr[offset+1]
                            // let b = ptr[offset+2]
                            let a = ptr[offset+3]
                            // print("X: \(x) Y: \(y) rgba = \(r) \(g) \(b) \(a)")
                            if a != 0 {
                                return false
                            }
                        }
                        return true
                    }

                    while w > minCharWidth {
                        if columnIsClear(w-1) {
                            w = w - 1
                        } else {
                            break
                        }
                    }
                    if w != charw {
                        // print("Trimming \(ch) image to \(w) pixels wide")
                        cgImage = cgImage.cropping(to: CGRect(x: 0, y: 0, width: w, height: charh))!
                    }
                }
                return Self.scaleUp(image: cgImage, factor: style.scale)
                // return addOutlineBaselineToImage(Self.scaleUp(image: cgImage, factor: style.scale))
            } else {
                // See if we have an individual image for it
                let charName = Self.getCharName(ch)
                var scaleForImage = 1
                var uiImage = UIImage(named: "fonts/\(fontName)/\(charName)@\(style.scale)")
                if uiImage == nil {
                    // Try an unscaled one we can scale up
                    uiImage = UIImage(named: "fonts/\(fontName)/\(charName)")
                    scaleForImage = style.scale
                }

                if let uiImage = uiImage {
                    var ciImage = CIImage(image: uiImage)!
                    if style.darkMode {
                        ciImage = ciImage.applyingFilter("CIColorInvert")
                    }
                    let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)!
                    return Self.scaleUp(image: cgImage, factor: scaleForImage)
                } else {
                    return nil
                }
            }
        }

        func addOutlineBaselineToImage(_ image: CGImage) -> CGImage {
            return CGImage.New(CGSize(width: image.width, height: image.height), flipped: true) { ctx in
                ctx.setStrokeColor(UIColor.yellow.cgColor)
                ctx.setLineWidth(1)
                let y = CGFloat(style.scaledAscent) + 0.5
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: CGFloat(image.width), y: y))
                ctx.addRect(CGRect(x: 0.5, y: 0.5, width: CGFloat(image.width) - 1, height: CGFloat(image.height) - 1))
                ctx.strokePath()
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
        }
    }

    private init() {}

    private func getImageDict(_ key: Style) -> ImagesDict {
        if let result = cache[key.toString()] {
            return result
        }
        let result = ImagesDict(forKey: key)
        cache[key.toString()] = result
        return result
    }

    func getImage(_ ch: Character, forStyle style: Style) -> CGImage {
        let imgDict = getImageDict(style)
        if let img = imgDict.getImageForChar(ch) {
            return img
        }

        let charName = ImagesDict.getCharName(ch)
        print("No font data for character \(charName)")

        let lineHeight = style.scaledHeight
        if style.font.bitmapName != Fonts.unifont.bitmapName && lineHeight >= Fonts.unifont.charh {
            // See if unifont has what we need (which it obviously will for any single-code-point character, but
            // we may still need to fall back to drawing a replacement image/char for composites)
            let unifontStyle = Style(font: Fonts.unifont, scale: 1, darkMode: style.darkMode)
            let unifontDict = getImageDict(unifontStyle)
            if let img = unifontDict.getImageForChar(ch) {
                // Potentially need to adjust the image height to match ours, taking into account where the baselines are
                let adjustedImage = Self.adjustImage(img, fromStyle: unifontStyle, toStyle: style)
                imgDict.setImageForChar(ch, image: adjustedImage)
                return img
            }
        }
        if let flagString = ch.flagString() {
            if lineHeight >= Fonts.guiConsFont.charh + 6 {
                let img = makeFlagImage(forString: flagString, style: style)
                imgDict.setImageForChar(ch, image: img)
                return img
            }
        }
        if lineHeight >= Fonts.guiConsFont.charh + 4 {
            // Then we have enough space to draw our replacement image box thing
            let img = makeReplacementImage(forCharName: charName, style: style)
            imgDict.setImageForChar(ch, image: img)
            return img
        } else {
            // Do we have replacement character?
            if imgDict.charInImage("\u{FFFD}") {
                return getImage("\u{FFFD}", forStyle: style)
            } else {
                // Assume it's a bitmap that uses 7f as a box char
                return getImage("\u{7F}", forStyle: style)
            }
        }
    }

    func makeReplacementImage(forCharName charName: String, style: Style) -> CGImage {
        let replacementStyle = BitmapFontCache.Style(font: Fonts.guiConsFont, scale: 1, darkMode: style.darkMode)

        let textWidth = getTextWidth(charName, forStyle: replacementStyle)
        let h = style.scaledHeight
        let w = textWidth + 8
        return CGImage.New(CGSize(width: w, height: h), flipped: true) { ctx in
            var x = 4
            let y = (h - replacementStyle.font.charh) / 2
            let col: CGFloat = style.darkMode ? 1 : 0
            ctx.setStrokeColor(red: col, green: col, blue: col, alpha: 1)
            ctx.stroke(CGRect(x: 0.5, y: 0.5, width: CGFloat(w) - 1, height: CGFloat(h) - 1))
            for ch in charName {
                let img = getImage(ch, forStyle: replacementStyle)
                ctx.draw(img, in: CGRect(x: x, y: y, width: img.width, height: img.height))
                x += img.width
            }
        }
    }

    func makeFlagImage(forString string: String, style: Style) -> CGImage {
        let replacementStyle = BitmapFontCache.Style(font: Fonts.guiConsFont, scale: 1, darkMode: style.darkMode)
        let textWidth = getTextWidth(string, forStyle: replacementStyle)
        let h = style.scaledHeight
        let w = textWidth + 6
        return CGImage.New(CGSize(width: w, height: h), flipped: true) { ctx in
            let col: CGFloat = style.darkMode ? 1 : 0
            ctx.setStrokeColor(red: col, green: col, blue: col, alpha: 1)
            let flagHeight = replacementStyle.scaledHeight + 4
            let flagPlusPoleHeight = (flagHeight * 3) / 2 // This is only if we actually have enough space for the whole pole
            let top = CGFloat(max(0, (h - flagPlusPoleHeight) / 2))
            let topLeft = CGPoint(x: 0.5, y: 0.5 + top)
            ctx.stroke(CGRect(origin: topLeft, size: CGSize(width: textWidth + 4, height: flagHeight - 1))) // flag box
            ctx.stroke(CGRect(origin: topLeft, size: CGSize(width: 0, height: flagPlusPoleHeight - 1))) // flag pole (may be truncated)
            var x: CGFloat = 2.0
            let y = top + 2.0
            for ch in string {
                let img = getImage(ch, forStyle: replacementStyle)
                let imgWidth = CGFloat(img.width)
                let imgHeight = CGFloat(img.height)
                ctx.draw(img, in: CGRect(x: x, y: y, width: imgWidth, height: imgHeight))
                x += imgWidth
            }
        }
    }

    static func adjustImage(_ img: CGImage, fromStyle: Style, toStyle: Style) -> CGImage {
        let fromHeight = fromStyle.scaledHeight
        let toHeight = toStyle.scaledHeight
        let adjustedY = max(0, toStyle.scaledAscent - fromStyle.scaledAscent)
        if adjustedY + fromHeight <= toHeight {
            // Line up the baselines
            return CGImage.New(CGSize(width: img.width, height: toHeight), flipped: true) { ctx in
                ctx.draw(img, in: CGRect(x: 0, y: adjustedY, width: img.width, height: img.height))
            }
        } else {
            return img
        }
    }

    func getTextWidth<T>(_ text: T, forStyle style: Style) -> Int where T : StringProtocol {
        var result = 0
        for ch in text {
            result = result + getCharWidth(ch, forStyle: style)
        }
        return result
    }

    func getCharWidth(_ char: Character, forStyle style: Style) -> Int {
        let imgDict = getImageDict(style)
        if imgDict.charInImage(char) && style.font.minWidth == nil {
            // Can't optimise unless it's a character within the image range and the image doesn't require trimming
            return style.font.charw * style.scale
        } else {
            return getImage(char, forStyle: style).width
        }
    }

    func emptyCache() {
        cache = [:]
    }

    static var shared = BitmapFontCache()
    private var cache: [String : ImagesDict] = [:] // Map of fontName_scale_theme key to ImagesDict
}
