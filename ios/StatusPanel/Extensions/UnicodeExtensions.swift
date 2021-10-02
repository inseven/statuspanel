// Copyright 2021 Jason Morley, Tom Sutcliffe
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

public enum UnicodeScalarEnum: UInt32 {
    case A = 0x41
    case a = 0x61
    case ZeroWidthJoiner = 0x200D

    case FemaleSign = 0x2640
    case MaleSign = 0x2642

    case VariationSelectorStart = 0xFE00
    case VariationSelectorEnd = 0xFE0F

    case RegionalIndicatorStart = 0x1F1E6
    case RegionalIndicatorEnd = 0x1F1FF

    case BlackFlag = 0x1F3F4

    case SkinToneStart = 0x1F3FB // Strictly speaking, EMOJI MODIFIER FITZPATRICK TYPE 
    case SkinToneEnd = 0x1F3FF

    case Tag_a = 0xE0061
    case Tag_z = 0xE007A
    case CancelTag = 0xE007F
}

public extension Unicode.Scalar {
    func inRange(_ lower: UnicodeScalarEnum, _ upper: UnicodeScalarEnum) -> Bool {
        let val = self.value
        return val >= lower.rawValue && val <= upper.rawValue
    }
}

public extension String.UnicodeScalarView {
    func get(_ index: Int) -> Unicode.Scalar? {
        // Allow -1 to mean last character, ie index self.count-1
        let realIndex = index < 0 ? self.count + index : index
        if realIndex < 0 || realIndex >= self.count {
            return nil
        }
        return self[self.index(self.startIndex, offsetBy: realIndex)]
    }

    func inRange(index: Int, _ lower: UnicodeScalarEnum, _ upper: UnicodeScalarEnum) -> Bool {
        guard let scalar = get(index) else {
            return false
        }
        return scalar.inRange(lower, upper)
    }

    func firstInRange(_ lower: UnicodeScalarEnum, _ upper: UnicodeScalarEnum) -> Bool {
        return inRange(index: 0, lower, upper)
    }

    func lastInRange(_ lower: UnicodeScalarEnum, _ upper: UnicodeScalarEnum) -> Bool {
        return inRange(index: -1, lower, upper)
    }

    func scalarAt(index: Int, equals value: UnicodeScalarEnum) -> Bool {
        guard let scalar = get(index) else {
            return false
        }
        return scalar.value == value.rawValue
    }

    func firstIs(_ value: UnicodeScalarEnum) -> Bool {
        return scalarAt(index: 0, equals: value)
    }

    func lastIs(_ value: UnicodeScalarEnum) -> Bool {
        return scalarAt(index: -1, equals: value)
    }
}
