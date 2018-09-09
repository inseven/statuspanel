//
//  DataSourceController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 09/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class DataSourceController {
	var sources: [DataSource] = []

	func add(dataSource: DataSource) {
		sources.append(dataSource)
		dataSource.fetchData(onCompletion: gotData)
	}

	func gotData(source: DataSource, data:[DataItem], error: Error?) {
		print(data)
	}
}
