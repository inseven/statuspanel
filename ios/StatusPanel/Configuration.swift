// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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

struct Configuration: Codable {

    var nationalRailApiToken: String

    var tflApiId: String
    var tflApiKey: String

    public enum CodingKeys: String, CodingKey {
        case nationalRailApiToken = "national-rail-api-token"
        case tflApiId = "tfl-api-id"
        case tflApiKey = "tfl-api-key"
    }

    static func load(path: URL) throws -> Configuration {
        let data = try Data(contentsOf: path)
        let configuration = try JSONDecoder().decode(Self.self, from: data)
        return configuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nationalRailApiToken = try container.decode(String.self, forKey: .nationalRailApiToken)
        tflApiId = try container.decode(String.self, forKey: .tflApiId)
        tflApiKey = try container.decode(String.self, forKey: .tflApiKey)
    }

}
