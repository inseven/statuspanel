// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

protocol DataSourceControllerDelegate: AnyObject {
    // Always called in context of main thread
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItemBase])
}

class DataSourceController {
    weak var delegate: DataSourceControllerDelegate?
    var sources: [GenericDataSource] = []
    var completed: [ObjectIdentifier: [DataItemBase]] = [:]
    var lock = NSLock()

    init() {
        let configuration = try! Bundle.main.configuration()
        add(dataSource: CalendarHeaderSource(identifier: .local(uuid: UUID()),
                                             defaults: CalendarHeaderSource.Settings(format: .variable(long: "yMMMMdEEE",
                                                                                                       short: "yMMMMdEEEE")),
                                             flags: [.header, .spansColumns]))
        add(dataSource: TFLDataSource(configuration: configuration, identifier: .global(source: .transportForLondon)))
        add(dataSource: NationalRailDataSource(configuration: configuration,
                                               identifier: .global(source: .nationalRail)))
        add(dataSource: CalendarSource(identifier: .global(source: .calendar)))
#if DEBUG
        add(dataSource: DummyDataSource())
#endif
        add(dataSource: CalendarSource(identifier: .global(source: .calendar), dayOffset: 1, header: "Tomorrow:"))
#if DEBUG
        add(dataSource: DummyDataSource())
#endif
    }

    fileprivate func add<T: DataSource>(dataSource: T) {
        sources.append(dataSource.wrapped())
    }

    func fetch() {
        print("Fetching")
        completed.removeAll()
        for source in sources {
//            source.fetchData(onCompletion: gotData)
            source.fetch(completion: gotData)
        }
    }

    func gotData(source: GenericDataSource, data: [DataItemBase]?, error: Error?) {
        let obj = ObjectIdentifier(source)
        lock.lock()
        completed[obj] = data
        // TODO something with error

        // TODO: Handle the nullable results?

        let allCompleted = (completed.count == sources.count)
        var items = [DataItemBase]()

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
