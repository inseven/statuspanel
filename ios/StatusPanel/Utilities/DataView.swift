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
