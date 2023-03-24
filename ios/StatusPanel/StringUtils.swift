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

struct StringUtils {

    static func splitLine<T>(_ line: T, maxWidth: Int, widthFn: (String) -> Int) -> [String] where T: StringProtocol {
        var result: [String] = []
        var components = line.split(separator: " ", maxSplits: Int.max, omittingEmptySubsequences: false).map({String($0)})
        var currentLine = ""
        var lineWidth = 0
        let spaceWidth = widthFn(" ")
        let newLine = {
            result.append(currentLine)
            currentLine = ""
            lineWidth = 0
        }
        let addToLine = {
            (text: String, width: Int) in
            currentLine.append(text)
            lineWidth += width
        }
        while components.count > 0 {
            let word = components.removeFirst()
            let wordWidth = widthFn(word)
            let lineAndWordWidth = lineWidth + wordWidth + (lineWidth == 0 ? 0 : spaceWidth)
            if lineAndWordWidth <= maxWidth {
                // Fits on current line
                if (currentLine != "") {
                    addToLine(" ", spaceWidth)
                }
                addToLine(word, wordWidth)
            } else if word.count > 1 && wordWidth > maxWidth / 2 {
                // It doesn't fit, and the 'word' is so big, forcibly split it
                let remainingLineSpace = maxWidth - (lineAndWordWidth - wordWidth)
                if remainingLineSpace > spaceWidth * 2 {
                    if (currentLine != "") {
                        addToLine(" ", spaceWidth)
                    }
                    var remainder = ""
                    for ch in word {
                        let chlen = widthFn(String(ch))
                        if lineWidth == 0 || lineWidth + chlen <= maxWidth {
                            addToLine(String(ch), chlen)
                        } else {
                            remainder.append(ch)
                            lineWidth = maxWidth
                        }
                    }
                    newLine()
                    components.insert(remainder, at: 0)
                } else {
                    // Just start a new line
                    newLine()
                    addToLine(word, wordWidth)
                }
            } else {
                newLine()
                addToLine(word, wordWidth)
            }
        }
        result.append(currentLine)
        return result
    }

    static func regex(_ text: String, pattern: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        var result: [String] = []
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        let nsstring = text as NSString
        regex.enumerateMatches(in: text, options: [], range: nsrange) { (match: NSTextCheckingResult?, _, stop) in
            guard let match = match else { return }
            // If there's only one match (ie no subgroups) return just it, otherwise
            // return just the subgroups.
            if match.numberOfRanges == 1 {
                result.append(nsstring.substring(with: match.range(at: 0)))
            } else {
                for i in 1 ..< match.numberOfRanges {
                    let range = match.range(at: i)
                    if range.location == NSNotFound {
                        continue
                    }
                    result.append(nsstring.substring(with: range))
                }
            }
        }
        return result
    }
}
