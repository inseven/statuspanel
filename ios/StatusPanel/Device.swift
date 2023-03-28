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

import Sodium

struct Device: Identifiable, Equatable, Hashable {

    enum Kind: String {
        case einkV1 = "0"
        case featherTft = "1"
        case demo = "2"
    }

    var kind: Kind
    var id: String
    var publicKey: String

    var size: CGSize {
        switch kind {
        case .einkV1, .demo:
            return CGSize(width: 640.0, height: 384.0)
        case .featherTft:
            return CGSize(width: 240.0, height: 135.0)
        }
    }

    var supportsTwoColumns: Bool {
        return size.width < 500
    }

    init(kind: Kind, id: String, publicKey: String) {
        self.kind = kind
        self.id = id
        self.publicKey = publicKey
    }

    // Create a new demo device identifier.
    init() {
        kind = .demo
        id = UUID().uuidString
        let sodium = Sodium()
        let keyPair = sodium.box.keyPair()!
        publicKey = sodium.utils.bin2base64(keyPair.publicKey, variant: .ORIGINAL)!
    }

}
