// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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

class DataView {

    let pointer: UnsafeMutableRawPointer
    let bytesPerPixel: Int
    let height: Int
    let width: Int

    init(pointer: UnsafeMutableRawPointer, bytesPerPixel: Int, width: Int, height: Int) {
        self.pointer = pointer
        self.bytesPerPixel = bytesPerPixel
        self.width = width
        self.height = height
    }

    func map(transform: (UInt8, UInt8, UInt8) -> (UInt8, UInt8, UInt8)) {
        for index in 0 ..< width * height {
            let offset = index * bytesPerPixel
            let red = pointer.load(fromByteOffset: offset, as: UInt8.self)
            let green = pointer.load(fromByteOffset: offset + 1, as: UInt8.self)
            let blue = pointer.load(fromByteOffset: offset + 2, as: UInt8.self)

            let (newRed, newGreen, newBlue) = transform(red, green, blue)
            pointer.storeBytes(of: newRed, toByteOffset: offset, as: UInt8.self)
            pointer.storeBytes(of: newGreen, toByteOffset: offset + 1, as: UInt8.self)
            pointer.storeBytes(of: newBlue, toByteOffset: offset + 2, as: UInt8.self)
        }
    }

}

extension UIImage {

    static func blankImage(size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image
    }

    public func normalizeOrientation() -> UIImage? {
        UIGraphicsBeginImageContext(size)
        defer {
            UIGraphicsEndImageContext()
        }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func atkinsonDither() -> UIImage? {

        guard let cgImage = self.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawdata = calloc(height*width*4, MemoryLayout<CUnsignedChar>.size)!
        defer {
            free(rawdata)
        }
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: rawdata,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var slidingErrorWindow: [CGFloat] = Array(repeating: 0, count: 2 * width)
        let mask = [0, 1, width - 2, width - 1, width, (2 * width) - 1]

        let pixels = DataView(pointer: rawdata, bytesPerPixel: bytesPerPixel, width: width, height: height)
        pixels.map { red, green, blue in

            let pixel: CGFloat = CGFloat(red) / 255.0

            let value = pixel + slidingErrorWindow.removeFirst()
            slidingErrorWindow.append(0)
            let color: CGFloat = value > 0.5 ? 1.0 : 0.0
            let error: CGFloat = (pixel - color) / 8.0
            for offset in mask {
                slidingErrorWindow[offset] = slidingErrorWindow[offset] + error
            }

            let newRed = UInt8(255.0 * color)
            return (newRed, newRed, newRed)
        }

        let resultImage = UIImage(cgImage: context.makeImage()!)

        return resultImage
    }

    func scaleAndDither(to size: CGSize) -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        let image = CIImage(cgImage: cgImage)
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputAspectRatioKey: 1.0,
                kCIInputScaleKey: size.width / self.size.width,
            ])
            .applyingFilter("CIPhotoEffectMono", parameters: [:])

        let context = CIContext(options: nil)
        guard let imageRef = context.createCGImage(image, from: CGRect(origin: .zero, size: size)) else {
            return nil
        }
        return UIImage(cgImage: imageRef)
            .atkinsonDither()
    }

}
