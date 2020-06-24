//
//  StringUtils.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

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
                        if lineWidth + chlen <= maxWidth {
                            addToLine(String(ch), chlen)
                        } else {
                            remainder.append(ch)
                            lineWidth = maxWidth
                        }
                    }
                    newLine()
                    components.append(remainder)
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
