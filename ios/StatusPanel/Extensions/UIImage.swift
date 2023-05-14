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

import SwiftUI
import UIKit

extension UIImage: Transferable {

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            guard let data = image.pngData() else {
                throw StatusPanelError.invalidImage
            }
            return data
        }
    }

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
        var slidingErrorWindow: [CGFloat] = Array(repeating: 0, count: 2 * width)
        let mask = [0, 1, width - 2, width - 1, width, (2 * width) - 1]
        let data = cgImage.mapPixels(numTasks: 1) { x, y, red, green, blue in
            let pixel: CGFloat = CGFloat(red) / 255.0
            let value = pixel + slidingErrorWindow.removeFirst()
            slidingErrorWindow.append(0)
            let color: CGFloat = value > 0.5 ? 1.0 : 0.0
            let error: CGFloat = (pixel - color) / 8.0
            for offset in mask {
                slidingErrorWindow[offset] = slidingErrorWindow[offset] + error
            }

            return UInt8(255.0 * color)
        }

        if let provider = CGDataProvider(data: Data(data) as CFData),
           let cgImage = CGImage(width: width,
                                 height: height,
                                 bitsPerComponent: 8,
                                 bitsPerPixel: 8,
                                 bytesPerRow: width,
                                 space: CGColorSpaceCreateDeviceGray(),
                                 bitmapInfo: .byteOrderDefault,
                                 provider: provider,
                                 decode: nil,
                                 shouldInterpolate: false,
                                 intent: .defaultIntent) {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }

    func scale(to size: CGSize, grayscale: Bool, contentMode: ContentMode) -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }

        let ratio = self.size.width / self.size.height
        let outputRatio = size.width / size.height

        // Determine the correct scale key.
        let scale: CGFloat
        switch contentMode {
        case .fit:
            if ratio > outputRatio {
                scale = size.width / self.size.width
            } else {
                scale = size.height / self.size.height
            }
        case .fill:
            if ratio > outputRatio {
                scale = size.height / self.size.height
            } else {
                scale = size.width / self.size.width
            }
        case .center:
            scale = 1.0
        }

        let scaledSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)

        var image = CIImage(cgImage: cgImage)
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputAspectRatioKey: 1.0,
                kCIInputScaleKey: scale,
            ])
            .applyingFilter("CIAffineTransform", parameters: [
                kCIInputTransformKey: CGAffineTransformMakeTranslation(-(scaledSize.width - size.width) / 2,
                                                                       -(scaledSize.height - size.height) / 2)
            ])
        if grayscale {
            image = image
                .applyingFilter("CIPhotoEffectMono", parameters: [:])
        }

        let context = CIContext(options: nil)
        guard let imageRef = context.createCGImage(image, from: CGRect(origin: .zero, size: size)) else {
            return nil
        }
        return UIImage(cgImage: imageRef)
    }

}
