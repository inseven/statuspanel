//
//  DataSource.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

protocol DataSource {
	func getData()
}

struct DataItem {
	init(_ text: String, sev: String = "info") {
	self.text = text
	self.sev = sev
	}
	let text: String
	let sev: String
}
