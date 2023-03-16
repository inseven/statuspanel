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

import DataStream

class RLEDecoder {

    struct Context {
        let count: UInt8
        let current: UInt8
    }

    let stream: DataReadStream
    var context: Context? = nil

    init(data: Data) {
        stream = DataReadStream(data: data)
    }

    func read() throws -> UInt8? {
        if stream.bytesAvailable < 1 {
            return nil
        }

        if let context = context {
            let count = context.count - 1
            if count > 0 {
                self.context = Context(count: count, current: context.current)
            } else {
                self.context = nil
            }
            return context.current
        } else {
            let value: UInt8 = try stream.read()
            if value == 255 {
                let count: UInt8 = try stream.read() - 1
                let current: UInt8 = try stream.read()
                if count > 0 {
                    self.context = Context(count: count, current: current)
                }
                return current
            } else {
                return value
            }

        }
    }

    func data() throws -> Data {
        let stream = DataWriteStream()
        while let value = try read() {
            try stream.write(value)
        }
        return stream.data!
    }

}
