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

protocol DataSource : AnyObject {
    typealias Callback = (DataSource, [DataItemBase], Error?) -> Void
    func fetchData(onCompletion:@escaping Callback)
}

enum DataItemFlag {
    case warning
    case header
}

protocol DataItemBase : AnyObject {
    func getPrefix() -> String
    func getText(checkFit: (String) -> Bool) -> String
    func getSubText() -> String?
    func getFlags() -> Set<DataItemFlag>
}

class DataItem : Equatable, DataItemBase {
    init(_ text: String, flags: Set<DataItemFlag> = Set()) {
        self.text = text
        self.flags = flags
    }

    let text: String
    let flags: Set<DataItemFlag>

    func getPrefix() -> String {
        return ""
    }

    func getText(checkFit: (String) -> Bool) -> String {
        return text
    }

    func getFlags() -> Set<DataItemFlag> {
        return flags
    }

    func getSubText() -> String? {
        return nil
    }

    static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.text == rhs.text && lhs.flags == rhs.flags
    }
}
