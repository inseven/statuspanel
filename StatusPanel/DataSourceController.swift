//
//  DataSourceController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 09/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

protocol DataSourceControllerDelegate: class {
    // Always called in context of main thread
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItem])
}

class DataSourceController {
    weak var delegate: DataSourceControllerDelegate?
    var sources: [DataSource] = []
    var completed: [ObjectIdentifier: [DataItem]] = [:]
    var lock = NSLock()

    func add(dataSource: DataSource) {
        sources.append(dataSource)
    }

    func fetch() {
        print("Fetching")
        completed.removeAll()
        for source in sources {
            source.fetchData(onCompletion: gotData)
        }
    }

    func gotData(source: DataSource, data:[DataItem], error: Error?) {
        let obj = ObjectIdentifier(source)
        lock.lock()
        completed[obj] = data
        // TODO something with error

        let allCompleted = (completed.count == sources.count)
        var items = [DataItem]()
        // We always want the calendar data source header as the first item
        items.append(CalendarSource.getHeader())

        // Use the ordering of sources, not completedItems
        for source in sources {
            let completedItems = completed[ObjectIdentifier(source)]
            items += completedItems ?? []
        }
        lock.unlock()

        if (allCompleted) {
            DispatchQueue.main.async {
                self.delegate?.dataSourceController(self, didUpdateData: items)
            }
        }
    }
}
