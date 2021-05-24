//
//  CGExtensions.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 20/06/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

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
    var center: CGPoint {
        get {
            return CGRect(origin: CGPoint(), size: self.size).center
        }
    }
}
