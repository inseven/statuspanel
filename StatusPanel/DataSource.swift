//
//  DataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

protocol DataSource : class {
    typealias Callback = (DataSource, [DataItemBase], Error?) -> Void
    func fetchData(onCompletion:@escaping Callback)
}

enum DataItemFlag {
    case warning
    case header
}

protocol DataItemBase : class {
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

class DummyDataSource : DataSource {
    func fetchData(onCompletion:@escaping Callback) {
        var data: [DataItemBase] = []
        #if targetEnvironment(simulator)
        if Config().showDummyData {
            var specialChars: [String] = []
            let images = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "fonts/font6x10") ?? []
            for imgName in images.map({$0.lastPathComponent}).sorted() {
                let parts = StringUtils.regex(imgName, pattern: #"U\+([0-9A-Fa-f]+)(?:_U\+([0-9A-Fa-f]+))*(?:@[2-4])?\.png"#)
                if parts.count == 0 {
                    continue
                }
                var scalars: [UnicodeScalar] = []
                for part in parts {
                    if let num = UInt32(part, radix: 16) {
                        if let scalar = UnicodeScalar(num) {
                            scalars.append(scalar)
                        }
                    }
                }
                if scalars.count != parts.count {
                    continue // Some weirdly formatted img name?
                }
                let str = String(String.UnicodeScalarView(scalars))
                specialChars.append(str)
            }
            let dummyData: [DataItemBase] = [
                CalendarItem(title: specialChars.joined(separator: ""), location: "All the emoji"),
                CalendarItem(time: "06:00", title: "Something that has really long text that needs to wrap. Like, really really long!", location: "A place that is also really really lengthy"),
                DataItem("Northern line: part suspended", flags: [.warning]),
                DataItem("07:44 to CBG:\u{2028}Cancelled", flags: [.warning]),
                CalendarItem(time: "09:40", title: "Some text wot is multiline", location: nil),
            ]
            data.append(contentsOf: dummyData)
        }
        #endif
        onCompletion(self, data, nil)
    }
}
