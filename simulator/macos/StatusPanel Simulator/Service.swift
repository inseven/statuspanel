// Copyright (c) 2018-2024 Jason Morley, Tom Sutcliffe
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

import DataStream

enum ServiceError: Error {
    case unsupportedUpdate
    case unsupportedEncoding
}

struct Service {

    enum Encoding: UInt16 {
        case rle = 0
        case png = 1
    }

    struct Update {
        let wakeupTime: Int
        let images: [NSImage]
    }

    static func update(configuration: DeviceConfiguration) async throws -> Update {

        let url = URL(string: "https://api.statuspanel.io/api/v3/status")!
            .appendingPathComponent(configuration.id.uuidString)

        let response = try await URLSession.shared.data(from: url)
        let data = response.0

        let stream = DataReadStream(data: data)

        // Check for a header marker.
        let marker: UInt16 = try stream.read()
        guard marker == 0xFF00 else {
            throw SimulatorError.invalidHeader
        }

        // Read the header.
        let headerLength: UInt8 = try stream.read()
        guard headerLength >= 8 else {
            throw ServiceError.unsupportedUpdate
        }

        let wakeupTime: UInt16 = try stream.read()
        let imageCount: UInt8 = try stream.read()
        let encodingValue: UInt16 = try stream.readLE()
        guard let encoding = Encoding(rawValue: encodingValue) else {
            throw ServiceError.unsupportedEncoding
        }

        // Read to the end of the header, ignoring remaining properties.
        let _ = try stream.read(count: Int(headerLength) - 8)

        // If an image count has been defined, then an index immediately follows the
        // header giving the index of each image.
        var offsets: [UInt32] = []
        for _ in 0..<imageCount {
            offsets.append(try stream.readLE())
        }

        // Convert the offsets to ranges by walking backwards through them and tracking
        // the previous offset as a length.
        var ranges: [(UInt32, UInt32)] = []
        var end: UInt32 = UInt32(data.count)
        for offset in offsets.reversed() {
            ranges.insert((offset, end), at: 0)
            end = offset
        }

        // Read the images from the stream, decrypt, decode RLE, expand 2BPP representation and convert to images.
        var images: [NSImage] = []
        for range in ranges {
            let length = range.1 - range.0
            let imageData = try stream.read(count: Int(length))
            images.append(try imageData
                .openSodiumSecretBox(keyPair: configuration.keyPair)
                .decode(encoding: encoding, size: configuration.size))
        }

        return Update(wakeupTime: Int(wakeupTime), images: images)
    }

}
