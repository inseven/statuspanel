// Copyright (c) 2018-2022 Jason Morley, Tom Sutcliffe
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

import CoreGraphics
import UIKit

class Panel {

    static let size = CGSize(width: 640.0, height: 384.0)
    static let statusBarHeight: CGFloat = 20.0

    static func blankImage() -> UIImage {
        return UIImage.blankImage(size: Panel.size, scale: 1.0)
    }

    static func privacyImage(from image: UIImage) throws -> UIImage? {
        guard let source = image
                .normalizeOrientation()?
                .scaleAndDither(to: Panel.size)
        else {
            return nil
        }
        return source
    }

    static func privacyImage(from image: UIImage, completion: @escaping (Result<UIImage?, Error>) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                completion(.success(try privacyImage(from: image)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func ARGBtoPanel(_ data: Data) -> Data {
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

    private static func rleEncode(_ data: Data) -> Data {
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

    static func rlePayloads(for images: [UIImage]) -> [(Data, UIImage)] {
        var result: [(Data, UIImage)] = []
        for (i, image) in images.enumerated() {
            let (rawdata, panelImage) = imgToARGBData(image)
            let panelData = ARGBtoPanel(rawdata)
            let rleData = rleEncode(panelData)
            do {
                let dir = try FileManager.default.documentsUrl()
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

    private static func imgToARGBData(_ image: UIImage) -> (Data, UIImage) {
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

    private static func flattenColours(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let col = UIColor.init(red: CGFloat(red) / 256,
                               green: CGFloat(green) / 256,
                               blue: CGFloat(blue) / 256,
                               alpha: 0)
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

}
