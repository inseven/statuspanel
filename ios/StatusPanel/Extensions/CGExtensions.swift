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

import UIKit

// I'm fed up of writing lots of boilerplate for moving and centering rects

extension CGPoint {
    static func + (left: CGPoint, right: (Int, Int)) -> CGPoint {
        return CGPoint(x: left.x + CGFloat(right.0), y: left.y + CGFloat(right.1))
    }

    static func - (left: CGPoint, right: (Int, Int)) -> CGPoint {
        return CGPoint(x: left.x - CGFloat(right.0), y: left.y - CGFloat(right.1))
    }

    static func + (left: CGPoint, right: (CGFloat, CGFloat)) -> CGPoint {
        return CGPoint(x: left.x + right.0, y: left.y + right.1)
    }

    static func - (left: CGPoint, right: (CGFloat, CGFloat)) -> CGPoint {
        return CGPoint(x: left.x - right.0, y: left.y - right.1)
    }
}

extension CGRect {
    var center: CGPoint {
        get {
            return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        }
        set {
            let currentValue = self.center
            self.origin = self.origin + (newValue.x - currentValue.x, newValue.y - currentValue.y)
        }
    }

    init(center: CGPoint, size: CGSize) {
        self.init(origin: center - (size.width / 2, size.height / 2), size: size)
    }

    func insetBy(left: CGFloat = 0, right: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0) -> CGRect {
        return CGRect(x: self.origin.x + left, y: self.origin.y + top, width: self.width - left - right, height: self.height - top - bottom)
    }

    func expandBy(left: CGFloat = 0, right: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0) -> CGRect {
        return self.insetBy(left: -left, right: -right, top: -top, bottom: -bottom)
    }

    func rectWithDifferentHeight(_ height: CGFloat) -> CGRect {
        return CGRect(origin: origin, size: CGSize(width: self.width, height: height))
    }
}

extension UIImage {
    static func New(_ size: CGSize, flipped: Bool, actions: (CGContext) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let uiImage = renderer.image { (uictx: UIGraphicsImageRendererContext) in
            let ctx = uictx.cgContext
            ctx.setAllowsAntialiasing(false)
            ctx.setShouldSubpixelQuantizeFonts(false)
            ctx.setShouldSubpixelPositionFonts(false)
            ctx.setShouldSmoothFonts(false)
            ctx.interpolationQuality = .none
            if flipped {
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.translateBy(x: 0, y: -size.height)
            }
            actions(ctx)
        }
        return uiImage
    }

    var center: CGPoint {
        get {
            return CGRect(origin: .zero, size: self.size).center
        }
    }
}

extension CGImage {
    static func New(width: Int, height:Int, flipped: Bool, actions: (CGContext) -> Void) -> CGImage {
        return New(CGSize(width: width, height: height), flipped: flipped, actions: actions)
    }

    static func New(_ size: CGSize, flipped: Bool, actions: (CGContext) -> Void) -> CGImage {
        return UIImage.New(size, flipped: flipped, actions: actions).cgImage!
    }
}
