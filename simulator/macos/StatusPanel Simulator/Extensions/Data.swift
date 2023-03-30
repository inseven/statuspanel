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

import Foundation
import SwiftUI

import Sodium

extension Data {

    func openSodiumSecretBox(keyPair: Box.KeyPair) throws -> Data {
        let sodium = Sodium()
        guard let bytes = withUnsafeBytes({ pointer in
            let bytes = Bytes(pointer)
            return sodium.box.open(anonymousCipherText: bytes,
                                   recipientPublicKey: keyPair.publicKey,
                                   recipientSecretKey: keyPair.secretKey)
        }) else {
            throw SimulatorError.decryptionFailure
        }
        return Data(bytes)
    }

    func decode(encoding: Service.Encoding, size: CGSize) throws -> NSImage {
        switch encoding {
        case .rle:
            return try self
                .decodeRLE()
                .expand2BPPValues()
                .rgbaImage(size: size)
        case .png:
            return NSImage(data: self)!  // TODO: Don't crash.
        }
    }

    func decodeRLE() throws -> Data {
        let decoder = RLEDecoder(data: self)
        return try decoder.data()
    }

    func expand2BPPValues() throws -> Data {

        let colorMap: [UInt8: UInt32] = [
            0: 0x000000FF,
            1: 0x7FFFD4FF,
            2: 0xFFFFFFFF,
        ]

        var data = Data(capacity: self.count * 4 * 4)
        
        for i in 0..<count {
            let byte = self[i]
            let pixel0 = UInt8((byte >> 0) & 3)
            data.append32(colorMap[pixel0] ?? 0xFFFFFFFF)

            let pixel1 = UInt8((byte >> 2) & 3)
            data.append32(colorMap[pixel1] ?? 0xFFFFFFFF)

            let pixel2 = UInt8((byte >> 4) & 3)
            data.append32(colorMap[pixel2] ?? 0xFFFFFFFF)

            let pixel3 = UInt8((byte >> 6) & 3)
            data.append32(colorMap[pixel3] ?? 0xFFFFFFFF)
        }

        return data
    }

    func rgbaImage(size: CGSize) -> NSImage {
        let dataProvider = CGDataProvider(data: self as NSData)!
        let cgImage = CGImage(width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bitsPerPixel: 32,
                              bytesPerRow: Int(size.width) * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: .byteOrderDefault,
                              provider: dataProvider,
                              decode: nil,
                              shouldInterpolate: true,
                              intent: .defaultIntent)!
        return NSImage(cgImage: cgImage)
    }

    public mutating func append32(_ newElement: UInt32) {
        append(UInt8((newElement >> 24) & 0xFF))
        append(UInt8((newElement >> 16) & 0xFF))
        append(UInt8((newElement >> 8) & 0xFF))
        append(UInt8((newElement >> 0) & 0xFF))
    }

}
