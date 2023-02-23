//
//  RLEDecoder.swift
//  StatusPanel Simulator
//
//  Created by Jason Barrie Morley on 23/02/2023.
//

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
