//
//  DataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

protocol DataSource : class {
	typealias Callback = (DataSource, [DataItem], Error?) -> Void
	func fetchData(onCompletion:@escaping Callback)
}

enum DataItemFlag {
	case warning
	case header
}

struct DataItem {
	init(_ text: String, flags: Set<DataItemFlag> = Set()) {
	self.text = text
	self.flags = flags
	}
	let text: String
	let flags: Set<DataItemFlag>
}


class DummyDataSource : DataSource {
	func fetchData(onCompletion:@escaping Callback) {
		let data = [
			DataItem("All day: Some event"),
			DataItem("6:00 PM: Something else that has really long text that needs to wrap"),
			DataItem("Northern line: part suspended", flags: [.warning]),
			DataItem("07:44 to CBG: Cancelled", flags: [.warning]),
			DataItem("Stuff 1"),
			DataItem("Stuff 2"),
			DataItem("Stuff 3"),
			DataItem("Stuff 4"),
			DataItem("Stuff 5"),
			DataItem("Stuff 6"),
			DataItem("Stuff 7"),
			DataItem("Stuff 8"),
			DataItem("Stuff 9"),
			DataItem("Stuff 10"),
			DataItem("Stuff 11"),
			DataItem("Stuff 12"),
		]
		onCompletion(self, data, nil)
	}
}
