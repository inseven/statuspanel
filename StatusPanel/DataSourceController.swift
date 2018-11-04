//
//  DataSourceController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 09/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

// Isn't there something that can do this in the standard library?
// TODO Y U NO WORK?
/*
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
*/

protocol DataSourceControllerDelegate: class {
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItem])
}

class DataSourceWrapper : Hashable {
    let value: DataSource
    init(_ obj: DataSource) {
        value = obj
    }
    static func ==(lhs: DataSourceWrapper, rhs: DataSourceWrapper) -> Bool {
        return lhs.value === rhs.value
    }
    var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }
}

class DataSourceController {
    weak var delegate: DataSourceControllerDelegate?
    var sources: [DataSource] = []
    var completionFn: (([DataItem], Bool) -> Void)?
    // var completed: [HashWrapper<DataSource> : [DataItem]] = [:]
    var completed: [DataSourceWrapper: [DataItem]] = [:]

    func add(dataSource: DataSource) {
        sources.append(dataSource)
    }

    func fetch() {
        completed.removeAll()
        for source in sources {
            source.fetchData(onCompletion: gotData)
        }
    }

    func gotData(source: DataSource, data:[DataItem], error: Error?) {
        // print(data)
        // let obj = HashWrapper<DataSource>(source)
        let obj = DataSourceWrapper(source)
        completed[obj] = data
        // TODO something with error

        let allCompleted = (completed.count == sources.count)
        var items = [DataItem]()
        // We always want the calendar data source header as the first item
        items.append(CalendarSource.getHeader())

        // Use the ordering of sources, not completedItems
        for source in sources {
            let completedItems = completed[DataSourceWrapper(source)]
            items += completedItems ?? []
        }
        if (allCompleted) {
            delegate?.dataSourceController(self, didUpdateData: items)
        }
    }
}
