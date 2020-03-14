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
    func format(width: Int) -> String
    func getFlags() -> Set<DataItemFlag>
}

class DataItem : Equatable, DataItemBase {
    init(_ text: String, flags: Set<DataItemFlag> = Set()) {
        self.text = text
        self.flags = flags
    }
    init(from: DataItemBase, width: Int) {
        self.text = from.format(width: width)
        self.flags = from.getFlags()
    }
    let text: String
    let flags: Set<DataItemFlag>

    func format(width: Int) -> String {
        return text
    }

    func getFlags() -> Set<DataItemFlag> {
        return flags
    }

    static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.text == rhs.text && lhs.flags == rhs.flags
    }
}

class DummyDataSource : DataSource {
    func fetchData(onCompletion:@escaping Callback) {
        let data: [DataItemBase] = [
            DataItem("All day: Some event"),
            DataItem("6:00 PM: Something else that has really long text that needs to wrap"),
            DataItem("Northern line: part suspended", flags: [.warning]),
            DataItem("07:44 to CBG:\u{2028}Cancelled", flags: [.warning]),
//            DataItem("123456789 1234567"),
//            DataItem("123456789 12345678"),
//            DataItem("123456789 123456789"),
            CalendarItem(time: "09:40", title: "Some text wot is multiline"),
            DataItem("10:40 Some text wot is multiline"),
//            DataItem("Stuff 2"),
//            DataItem("Stuff 3"),
//            DataItem("Stuff 4"),
//            DataItem("Tomorrow:", flags: [.header]),
//            DataItem("Stuff 5"),
//            DataItem("Stuff 6"),
//            DataItem("Stuff 7"),
//            DataItem("Stuff 8"),
//            DataItem("Stuff 9"),
//            DataItem("Stuff 10"),
//            DataItem("Stuff 11"),
//            DataItem("Stuff 12"),
        ]
        onCompletion(self, data, nil)
    }
}
