// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

struct DataItemFlags: OptionSet, Codable {

    enum Style {
        case title
        case body
    }

    let rawValue: Int

    static let warning = DataItemFlags(rawValue: 1 << 0)
    static let header = DataItemFlags(rawValue: 1 << 1)
    static let prefersNewSection = DataItemFlags(rawValue: 1 << 2)
    static let spansColumns = DataItemFlags(rawValue: 1 << 3)

    var labelStyle: LabelStyle {
        if contains(.header) {
            return .header
        }
        return .text
    }

    var style: Style {
        get {
            if contains(.header) {
                return .title
            }
            return .body
        }
        set {
            switch newValue {
            case .title:
                insert(.header)
            case .body:
                remove(.header)
            }
        }
    }

}
