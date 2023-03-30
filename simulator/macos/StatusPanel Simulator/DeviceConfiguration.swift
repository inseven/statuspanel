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

struct DeviceConfiguration: Codable, Equatable {

    static func == (lhs: DeviceConfiguration, rhs: DeviceConfiguration) -> Bool {
        return lhs.id == rhs.id
    }

    enum Kind: String, Codable {
        case einkV1 = "0"
        case featherTft = "1"
        case demo = "2"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case publicKey
        case secretKey
        case kind
    }

    let id: UUID
    let keyPair: Box.KeyPair
    let kind: Kind

    var pairingURL: URL {
        let sodium = Sodium()
        let publicKeyBase64 = sodium.utils.bin2base64(keyPair.publicKey, variant: .ORIGINAL)!
        var components = URLComponents()
        components.scheme = "statuspanel"
        components.path = "r2"
        components.queryItems = [
            URLQueryItem(name: "id", value: id.uuidString),
            URLQueryItem(name: "pk", value: publicKeyBase64),
            URLQueryItem(name: "t", value: kind.rawValue),
        ]
        return components.url!
    }

    var size: CGSize {
        switch kind {
        case .einkV1, .demo:
            // TODO: The decoding runs out of pixels for some reason!
            return CGSize(width: 640.0, height: 380.0)
        case .featherTft:
            return CGSize(width: 240.0, height: 135.0)
        }
    }

    init(kind: Kind = .einkV1) {
        self.id = UUID()
        self.keyPair = Sodium().box.keyPair()!
        self.kind = kind
    }

    init(id: UUID, keyPair: Box.KeyPair) {
        self.id = id
        self.keyPair = keyPair
        self.kind = .einkV1
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        let id = UUID(uuidString: idString)!
        let sodium = Sodium()
        let publicKeyString = try container.decode(String.self, forKey: .publicKey)
        let publicKey = sodium.utils.base642bin(publicKeyString, variant: .ORIGINAL)!
        let secretKeyString = try container.decode(String.self, forKey: .secretKey)
        let secretKey = sodium.utils.base642bin(secretKeyString, variant: .ORIGINAL)!
        let kind = (try? container.decode(Kind.self, forKey: .kind)) ?? .einkV1
        self.id = id
        self.keyPair = Box.KeyPair(publicKey: publicKey, secretKey: secretKey)
        self.kind = kind
    }

    func encode(to encoder: Encoder) throws {
        let sodium = Sodium()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(sodium.utils.bin2base64(keyPair.publicKey, variant: .ORIGINAL)!, forKey: .publicKey)
        try container.encode(sodium.utils.bin2base64(keyPair.secretKey, variant: .ORIGINAL)!, forKey: .secretKey)
        try container.encode(kind, forKey: .kind)
    }


}
