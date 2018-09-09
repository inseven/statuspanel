//
//  DataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

protocol DataSource {
	typealias Callback = (DataSource, [DataItem], Error?) -> Void
	func fetchData(onCompletion:@escaping Callback)
}

enum DataItemFlag {
	case warning
}

struct DataItem {
	init(_ text: String, flags: Set<DataItemFlag> = Set()) {
	self.text = text
	self.flags = flags
	}
	let text: String
	let flags: Set<DataItemFlag>
}
