//
//  StringUtils.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

//import Foundation

struct StringUtils {

    static func splitLine(_ line: String, maxChars: Int, inset: String = "") -> [String] {
        var result: [String] = []
        var components = line.split(separator: " ", maxSplits: Int.max, omittingEmptySubsequences: false)
        var currentLine = ""
        while components.count > 0 {
            repeat {
                if (currentLine.count > 0) {
                    currentLine.append(" ")
                }
                currentLine.append(contentsOf: components.remove(at: 0))
            } while (components.count > 0 && (currentLine.count + components[0].count) < maxChars)
            result.append(currentLine)
            currentLine = inset
        }
        return result
    }

}
