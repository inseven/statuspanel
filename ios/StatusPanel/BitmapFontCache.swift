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

    // Contains all the info required to render a character: the font bitmap to use, the scale, and the dark mode
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

        func getImageForChar(_ char: Character) -> CGImage? {
            // First try and remove any modifiers from the character which we can't represent and don't care about
            var scalars = char.unicodeScalars
            while scalars.count > 1 {
                let lastScalar = scalars.last?.value ?? 0
                if lastScalar >= 0xFE00 && lastScalar <= 0xFE0F {
                    // Variation selector, particularly U+FE0E and U+FE0F for emoji-style and text-only style.
                    scalars.removeLast()
                } else if lastScalar >= 0x1F3FB && lastScalar <= 0x1F3FF {
                    // Skin tone modifier
                    scalars.removeLast()
                } else {
                    break
                }
            }
            let ch = Character(String(scalars))

            if let img = charMap[ch] {
                return img
            }
            if let img = createImageForChar(ch) {
                setImageForChar(ch, image: img)
                return img
            }
            return nil
        }

        func setImageForChar(_ ch: Character, image: CGImage) {
            charMap[ch] = image
        }

        func charInImage(_ char: Character) -> Bool {
            if char.unicodeScalars.count != 1 {
                return false
            }
            let scalarValue = char.unicodeScalars.first!.value
            let maxValue = font.startIndex.value + UInt32(self.charsPerRow * self.numRows)
            return scalarValue >= font.startIndex.value && scalarValue < maxValue
        }

        // Must be an easier way than this...
        // Note this effectively also does a flip, thanks to rendering a CGImage in a context
        static func scaleUp(image unscaledCGImage: CGImage, factor: Int) -> CGImage {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1.0
            let scaleFactor = CGFloat(factor)
            let unscaledWidth = CGFloat(unscaledCGImage.width)
            let unscaledHeight = CGFloat(unscaledCGImage.height)
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

        static func getCharName(_ ch: Character) -> String {
            return ch.unicodeScalars.map({ String(format:"U+%04X", $0.value) }).joined(separator: "_")
        }

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
                return ImagesDict.scaleUp(image: cgImage, factor: style.scale)
            } else {
                // See if we have an individual image for it
                let charName = ImagesDict.getCharName(ch)
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
                    return ImagesDict.scaleUp(image: cgImage, factor: scaleForImage)
                } else {
                    return nil
                }
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

        let lineHeight = style.font.charh * style.scale
        if style.font.bitmapName != Fonts.unifont.bitmapName && lineHeight >= Fonts.unifont.charh {
            // See if unifont has what we need (which it obviously will for any single-code-point character, but
            // we may still need to fall back to drawing a replacement image/char for composites
            let unifontDict = getImageDict(Style(font: Fonts.unifont, scale: 1, darkMode: style.darkMode))
            if let img = unifontDict.getImageForChar(ch) {
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
        let h = style.font.charh * style.scale
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
            let y = (h - replacementStyle.font.charh) / 2
            ctx.setLineWidth(CGFloat(style.scale))
            let col: CGFloat = style.darkMode ? 1 : 0
            ctx.setStrokeColor(red: col, green: col, blue: col, alpha: 1)
            ctx.stroke(CGRect(x: 0, y: 0, width: w, height: h))
            for ch in charName {
                let img = getImage(ch, forStyle: replacementStyle)
                ctx.draw(img, in: CGRect(x: x, y: y, width: img.width, height: img.height))
                x += img.width
            }
        }
        return uiImage.cgImage!
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
