//
//  StringUtils.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

//import Foundation

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
}
