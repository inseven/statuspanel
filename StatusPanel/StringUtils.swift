//
//  StringUtils.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import Foundation

struct StringUtils {

    static func splitLine(_ line: String, maxWidth: Int, widthFn: (String) -> Int) -> [String] {
        var result: [String] = []
        var components = line.split(separator: " ", maxSplits: Int.max, omittingEmptySubsequences: false)
        var currentLine = ""
        var lineWidth = 0
        let spaceWidth = widthFn(" ")
        while components.count > 0 {
            let word = components.removeFirst()
            let wordWidth = widthFn(String(word))
            let lineAndWordWidth = lineWidth + wordWidth + (lineWidth == 0 ? 0 : spaceWidth)
            if lineAndWordWidth <= maxWidth {
                // Add to current line
                if (currentLine != "") {
                    currentLine.append(" ")
                }
                currentLine.append(String(word))
                lineWidth = lineAndWordWidth
            } else {
                // Start a new line
                result.append(currentLine)
                currentLine = String(word)
                lineWidth = wordWidth
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
                result.append(nsstring.substring(with: match.range(at: 1)))
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
