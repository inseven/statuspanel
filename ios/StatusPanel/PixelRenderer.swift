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

import Foundation
import UIKit

// These must match the order of colours defined in inky.lua (and thus what colours the panel supports)
private let InkyPalette: [UIColor] = [
    .black,
    .white,
    .green,
    .blue,
    .red,
    .yellow,
    .orange
]

struct PixelRenderer: Renderer {

    private enum DividerStyle {
        case vertical(originY: CGFloat)
        case horizontal(originY: CGFloat)
    }

    func render(data: [DataItemBase], config: Config, device: Device, settings: DeviceSettings) -> [UIImage] {
        dispatchPrecondition(condition: .onQueue(.main))
        let image = Self.renderImage(data: data, config: config, device: device, settings: settings)
        let privacyImage = Self.renderPrivacyImage(data: data, config: config, device: device, settings: settings)
        if device.kind == .pimoroniInkyImpression4 {
            let imagePalettized = Self.palettize(image: image.cgImage!, colours: InkyPalette, dither: false)
            let privacyPalettized = Self.palettize(image: privacyImage.cgImage!, colours: InkyPalette, dither: true)
            return [UIImage(cgImage: imagePalettized), UIImage(cgImage: privacyPalettized)]
        }
        return [image, privacyImage]
    }

    private static func renderImage(data: [DataItemBase],
                                    config: Config,
                                    device: Device,
                                    settings: DeviceSettings,
                                    redact: Bool = false) -> UIImage {
        dispatchPrecondition(condition: .onQueue(.main))

        let contentView = UIView(frame: CGRect(origin: .zero, size: device.size))
        contentView.contentScaleFactor = 1.0

        // Construct the contentView's contents. For now just make labels and flow them into 2 columns
        contentView.backgroundColor = settings.displaysInDarkMode ? UIColor.black : UIColor.white
        let foregroundColor = settings.displaysInDarkMode ? UIColor.white : UIColor.black
        let twoCols = device.supportsTwoColumns ? false : settings.displayTwoColumns
        let showIcons = settings.showIcons
        let rect = contentView.frame
        let maxy = rect.height - 10 // Leave space for status line
        let midx = rect.width / 2
        var x : CGFloat = 5
        var y : CGFloat = 0
        let colWidth = twoCols ? (rect.width / 2 - x * 2) : rect.width - x
        let bodyFont = Fonts.font(named: settings.bodyFont)
        let itemGap = device.kind == .featherTft ? 4 : CGFloat(min(10, bodyFont.textHeight / 2)) // ie 50% of the body text line height up to a max of 10px
        var colStart = y
        var col = 0
        var columnItemCount = 0 // Number of items assigned to the current column
        var divider: DividerStyle? = twoCols ? .vertical(originY: 0) : nil
        let redactMode: RedactMode = (redact ? (settings.privacyMode == .redactWords ? .redactWords : .redactLines) : .none)
        let colorHint: UILabel.ColorHint = device.kind == .pimoroniInkyImpression4 ? .inkyPalette : .monochrome

        for item in data {

            let flags = item.flags
            let font = flags.contains(.header) ? settings.titleFont : settings.bodyFont
            let fontDetails = Fonts.font(named: font)
            let w = flags.contains(.spansColumns) ? rect.width : colWidth
            let frame = CGRect(x: x, y: y, width: w, height: 0)
            let view = UIView(frame: frame)
            var prefix = fontDetails.supportsEmoji && showIcons ? item.iconAndPrefix : item.prefix
            let numPrefixLines = prefix.split(separator: "\n").count
            var textFrame = CGRect(origin: CGPoint.zero, size: frame.size)
            var itemHeight: CGFloat = 0

            if !prefix.isEmpty {
                let prefixLabel = UILabel.getLabel(frame: textFrame,
                                                   font: font,
                                                   style: flags.labelStyle,
                                                   colorHint: colorHint,
                                                   redactMode: redactMode)
                prefixLabel.textColor = (device.isFullColor && !redact) ? (item.accentColor ?? foregroundColor) : foregroundColor
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
            let label = UILabel.getLabel(frame: textFrame,
                                         font: font,
                                         style: flags.labelStyle,
                                         colorHint: colorHint,
                                         redactMode: redactMode)
            label.numberOfLines = 1 // Temporarily while we're using it in checkFit

            let text = prefix + item.getText(checkFit: { (string: String) -> Bool in
                label.text = prefix + string
                let size = label.sizeThatFits(textFrame.size)
                return size.width <= textFrame.width
            })
            label.textColor = foregroundColor
            if flags.contains(.warning) && !redact {
                // Icons don't render well on the panel, use a coloured background instead
                label.backgroundColor = UIColor.yellow
                label.textColor = UIColor.black
            }
            label.numberOfLines = settings.maxLines
            label.lineBreakMode = .byTruncatingTail
            label.text = text
            label.sizeToFit()
            itemHeight = max(itemHeight, label.bounds.height)
            label.frame = CGRect(x: label.frame.minX,
                                 y: label.frame.minY,
                                 width: textFrame.width,
                                 height: label.frame.height)
            view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: itemHeight))
            view.addSubview(label)
            if let subText = item.subText {
                let subLabel = UILabel.getLabel(frame: textFrame,
                                                font: font,
                                                style: .subText,
                                                colorHint: colorHint,
                                                redactMode: redactMode)
                subLabel.textColor = foregroundColor
                subLabel.numberOfLines = settings.maxLines
                subLabel.text = subText
                subLabel.sizeToFit()
                subLabel.frame = CGRect(x: textFrame.minX, y: view.bounds.maxY + 1, width: textFrame.width, height: subLabel.frame.height)
                view.frame = CGRect(origin: view.frame.origin,
                                    size: CGSize(width: view.frame.width, height: subLabel.frame.maxY))
                view.addSubview(subLabel)
            }
            let sz = view.frame
            // Enough space for this item?
            let itemIsColBreak = (columnItemCount > 0 && flags.contains(.prefersNewSection))
            if (col == 0 && twoCols && (sz.height > maxy - y || itemIsColBreak)) {
                // overflow to 2nd column
                col += 1
                columnItemCount = 0
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

            y = y + sz.height + itemGap

            if twoCols && flags.contains(.spansColumns) {
                // Update the verticial origin of the divider and columns, and start at column 0 again.
                divider = .vertical(originY: y)
                colStart = y
                columnItemCount = 0
                col = 0
            } else {
                // Track the number of items in the current column.
                columnItemCount += 1
            }

        }

        // And render it into an image
        let result = UIImage.New(rect.size, flipped: false) { context in
            // layer.render() works when the device is locked, whereas drawHierarchy() doesn't
            contentView.layer.render(in: context)

            // Draw the dividing line.
            if let divider = divider {

                context.setStrokeColor(foregroundColor.cgColor)
                context.beginPath()

                switch divider {
                case .vertical(let originY):
                    context.move(to: CGPoint(x: midx, y: originY))
                    context.addLine(to: CGPoint(x: midx, y: rect.height - device.statusBarHeight))
                case .horizontal(let originY):
                    context.move(to: CGPoint(x: x, y: originY))
                    context.addLine(to: CGPoint(x: rect.width - x, y: originY))
                }

                context.drawPath(using: .stroke)
            }
        }
        return result
    }

    private static func renderPrivacyImage(data: [DataItemBase],
                                           config: Config,
                                           device: Device,
                                           settings: DeviceSettings) -> UIImage {
        switch settings.privacyMode {
        case .redactLines, .redactWords:
            return renderImage(data: data, config: config, device: device, settings: settings, redact: true)
        case .customImage:

            guard let privacyImageFilename = settings.privacyImage,
                  let privacyImage = try? PrivacyImageManager.privacyImage(filename: privacyImageFilename)
            else {
                return device.blankImage()
            }

            if device.isFullColor {
                if let image = privacyImage.scale(to: device.size,
                                                  grayscale: false,
                                                  contentMode: settings.privacyImageContentMode) {
                    return image
                }
                print("Failed to scale privacy image.")
                return device.blankImage()
            } else {
                if let image = Panel.privacyImage(from: privacyImage,
                                                  size: device.size,
                                                  contentMode: settings.privacyImageContentMode) {
                    return image
                }
                print("Failed to generate privacy image.")
                return device.blankImage()
            }
        }
    }

    // Match on closeness of hue rather than manhattan proximity in the RGB colour space
    private static func colourClosestTo(r: CGFloat, g: CGFloat, b: CGFloat, hsbColours: [CGFloat]) -> UInt8 {
        let (h, s, b) = UIColor(red: r, green: g, blue: b, alpha: 1.0).hsb()
        var closestDistance: CGFloat = 1.0
        var idx: UInt8? = nil
        let numColours = hsbColours.count / 3
        for i in 0 ..< numColours {
            let pos = i * 3
            if hsbColours[pos+2] < 0.2 {
                // Black
                if b < 0.2 {
                    return UInt8(i)
                } else {
                    // Don't compare the hue on black
                    continue
                }
            } else if (hsbColours[pos + 2] > 0.9 && hsbColours[pos + 1] < 0.1) {
                // White
                if b > 0.8 && s < 0.2 {
                    return UInt8(i)
                } else {
                    // Don't compare hue on white
                    continue
                }
            }
            var hDistance = abs(h - hsbColours[pos])
            if hDistance > 0.5 {
                hDistance = 1 - hDistance
            }

            if hDistance < closestDistance {
                closestDistance = hDistance
                idx = UInt8(i)
            }
        }
        return idx!
    }

    private static func palettize(image: CGImage, colours: [UIColor], dither: Bool) -> CGImage {
        let startTime = Date.now
        let palette = [UInt8](unsafeUninitializedCapacity: colours.count * 3) { buffer, initializedCount in
            var i = 0
            for colour in colours {
                let (r, g, b) = colour.rgb()
                buffer[i] = UInt8(r * 255)
                buffer[i+1] = UInt8(g * 255)
                buffer[i+2] = UInt8(b * 255)
                i = i + 3
            }
            initializedCount = i
        }
        let hsbColours = [CGFloat](unsafeUninitializedCapacity: colours.count * 3) { buffer, initializedCount in
            var i = 0
            for colour in colours {
                let (h, s, b) = colour.hsb()
                buffer[i] = h
                buffer[i+1] = s
                buffer[i+2] = b
                i = i + 3
            }
            initializedCount = i
        }
        let spc = CGColorSpace(indexedBaseSpace: CGColorSpace(name: CGColorSpace.sRGB)!, last: colours.count - 1, colorTable: palette)!
        let w = image.width
        let h = image.height

        // Convenience struct for temp pixel data
        struct Pixel {
            var r: CGFloat; var g: CGFloat; var b: CGFloat; var idx: UInt8?
            init(r: CGFloat, g: CGFloat, b: CGFloat) {
                self.r = r
                self.g = g
                self.b = b
                self.idx = nil
            }
            init(index: UInt8, inPalette colours: [UIColor]) {
                let colour = colours[Int(index)]
                let (r, g, b) = colour.rgb()
                self.r = r
                self.g = g
                self.b = b
                self.idx = index
            }
            mutating func apply(delta: Pixel, proportion: Int) {
                self.r = self.r + ((delta.r * CGFloat(proportion)) / 16.0)
                self.g = self.g + ((delta.g * CGFloat(proportion)) / 16.0)
                self.b = self.b + ((delta.b * CGFloat(proportion)) / 16.0)
                self.idx = nil
            }
        }
        var data: [UInt8]
        if dither {
            var pixels = image.mapPixels { x, y, r, g, b in
                return Pixel(r: CGFloat(r) / 255, g: CGFloat(g) / 255, b: CGFloat(b) / 255)
            }
            // Apply a Floyd-Steinberg dither
            for y in 0 ..< h {
                for x in 0 ..< w {
                    let old = pixels[y*w + x]
                    let new = Pixel(index: colourClosestTo(r: old.r, g: old.g, b: old.b, hsbColours: hsbColours), inPalette: colours)
                    pixels[y*w + x] = new
                    let delta = Pixel(r: old.r - new.r, g: old.g - new.g, b: old.b - new.b)
                    if x + 1 < w {
                        pixels[y * w + x+1].apply(delta: delta, proportion: 7)
                    }
                    if y + 1 < h {
                        if x > 0 {
                            pixels[(y+1) * w + x-1].apply(delta: delta, proportion: 3)
                        }
                        pixels[(y+1) * w + x].apply(delta: delta, proportion: 5)
                        if x + 1 < w {
                            pixels[(y+1) * w + x+1].apply(delta: delta, proportion: 1)
                        }
                    }
                }
            }

            data = Array<UInt8>()
            for pixel in pixels {
                data.append(pixel.idx!)
            }
        } else {
            data = image.mapPixels { x, y, r, g, b in
                return colourClosestTo(r: CGFloat(r) / 255, g: CGFloat(g) / 255, b: CGFloat(b) / 255, hsbColours: hsbColours)
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        print("Palettize took \(startTime.distance(to: Date.now))")
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: spc,
                       bitmapInfo: .byteOrderDefault, provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }
}
