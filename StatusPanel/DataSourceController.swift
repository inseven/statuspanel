//
//  DataSourceController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 09/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

// Isn't there something that can do this in the standard library?
class HashWrapper<T:AnyObject> : Hashable {
	let value: T
	init(_ obj: T) {
		value = obj
	}
	static func ==(lhs: HashWrapper<T>, rhs: HashWrapper<T>) -> Bool {
		return lhs.value === rhs.value
	}
	var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }
}

class DataSourceController {
	var sources: [DataSource] = []
	var completionFn: (([DataItem], Bool) -> Void)?
	//var data = [DataSource:[DataItem]]()
	var completed: [HashWrapper<DataSource> : [DataItem]] = [:]

	func add(dataSource: DataSource) {
		sources.append(dataSource)
	}

	func fetchAllData(onCompletion:@escaping ([DataItem], Bool) -> Void) {
		completionFn = onCompletion
		for source in sources {
			source.fetchData(onCompletion: gotData)
		}
	}

	func gotData(source: DataSource, data:[DataItem], error: Error?) {
		print(data)
		var obj = HashWrapper<DataSource>(source)
		completed[obj] = data
		// TODO something with error
	}
}
