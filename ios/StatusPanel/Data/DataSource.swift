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

struct DisplayContext {
    init(showBodyIcons: Bool, showHeaderIcons: Bool) {
        self.showBodyIcons = showBodyIcons
        self.showHeaderIcons = showHeaderIcons
    }

    func shouldShowIcons(isHeader: Bool) -> Bool {
        return isHeader ? showHeaderIcons : showBodyIcons
    }

    private let showBodyIcons: Bool
    private let showHeaderIcons: Bool
}

protocol DataSource : AnyObject {
    typealias Callback = (DataSource, [DataItemBase], Error?) -> Void
    func fetchData(displayContext: DisplayContext, onCompletion:@escaping Callback)
}

struct DataItemFlags: OptionSet {

    let rawValue: Int

    static let warning = DataItemFlags(rawValue: 1 << 0)
    static let header = DataItemFlags(rawValue: 1 << 1)
    static let prefersEmptyColumn = DataItemFlags(rawValue: 1 << 2)
    static let spansColumns = DataItemFlags(rawValue: 1 << 3)
}

protocol DataItemBase : AnyObject {

    var prefix: String { get }
    var flags: DataItemFlags { get }
    var subText: String? { get }

    func getText(checkFit: (String) -> Bool) -> String
}

class DataItem : Equatable, DataItemBase {

    let prefix: String
    private let text: String
    let flags: DataItemFlags

    init(prefix: String, text: String, flags: DataItemFlags = []) {
        self.prefix = prefix
        self.text = text
        self.flags = flags
    }

    convenience init(text: String, flags: DataItemFlags = []) {
        self.init(prefix: "", text: text, flags: flags)
    }

    var subText: String? { nil }

    func getText(checkFit: (String) -> Bool) -> String {
        return text
    }

    static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.prefix == rhs.prefix && lhs.text == rhs.text && lhs.flags == rhs.flags
    }
}
