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

import Combine
import Foundation

enum DataSourceType: String, Codable {

    case calendar = "io.statuspanel.source.calendar"
    case calendarHeader = "io.statuspanel.source.calendar-header"
    case dummy = "io.statuspanel.source.dummy"
    case nationalRail = "io.statuspanel.source.national-rail"
    case text = "io.statuspanel.source.text"
    case transportForLondon = "io.statuspanel.source.transport-for-london"

}

struct DataSourceTuple: Codable {

    var type: DataSourceType
    var identifier: UUID

}

protocol DataSourceControllerDelegate: AnyObject {
    // Always called in context of main thread
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItemBase])
    func dataSourceController(_ dataSourceController: DataSourceController, didFailWithError error: Error)

    // TODO: Consder doing it this way?
//    func dataSourceController(_ dataSourceController: DataSourceController, didAddSourceAtIndex index: Int)
}

class DataSourceController {

    var cancellable: Cancellable?

    weak var delegate: DataSourceControllerDelegate?
    var sources: [DataSourceInstance] = []

    var factories: [DataSourceType: DataSourceWrapper] = [:]
    var dataSources: [DataSourceWrapper] { Array(factories.values) }

    init() {

        // TODO: Ensure this is thread safe (aka always called on the main thread?)

        let configuration = try! Bundle.main.configuration()
        factories = [
            .calendar: CalendarSource().wrapped(),
            .calendarHeader: CalendarHeaderSource().wrapped(),
            .dummy: DummyDataSource().wrapped(),
            .nationalRail: NationalRailDataSource(configuration: configuration).wrapped(),
            .text: TextDataSource().wrapped(),
            .transportForLondon: TFLDataSource(configuration: configuration).wrapped(),
        ]

        let config = Config()
        add(type: .calendarHeader,
            settings: CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                                    shortFormat: "yMMMMdEEE",
                                                    flags: [.header, .spansColumns],
                                                    offset: 0,
                                                    component: .day))
        add(type: .transportForLondon,
            settings: TFLDataSource.Settings(lines: config.activeTFLLines))
        add(type: .nationalRail,
            settings: NationalRailDataSource.Settings(routes: config.trainRoutes))
        add(type: .calendar,
            settings: CalendarSource.Settings(calendars: config.activeCalendars,
                                              showLocations: config.showCalendarLocations,
                                              showUrls: config.showUrlsInCalendarLocations))
        add(type: .text,
            settings: TextDataSource.Settings(flags: [.prefersEmptyColumn],
                                              text: "Tomorrow:"))
        add(type: .calendar,
            settings: CalendarSource.Settings(calendars: config.activeCalendars,
                                              showLocations: config.showCalendarLocations,
                                              showUrls: config.showUrlsInCalendarLocations,
                                              offset: 1))
    }

    // TODO: This can fail and we should probably handle an error during this initialization.
    // TODO: We probably don't need this method?
    fileprivate func add(type: DataSourceType) {
        guard let dataSource = factories[type] else {
            print("Failed to instantiate data source with type '\(type.rawValue)'.")
            return
        }
        sources.append(DataSourceInstance(id: UUID(), dataSource: dataSource))
    }

    // TODO: Can we make this safe by somehow associating the type with the enum?
    fileprivate func add<T: DataSourceSettings>(type: DataSourceType, settings: T) {
        guard let dataSource = factories[type] else {
            // TODO: Handle failure.
            print("Failed to instantiate data source with type '\(type.rawValue)'.")
            return
        }
        // TODO: Validate the settings type.
        assert(dataSource.validate(settings: settings))
        let uuid = UUID()
        try! Config().save(settings: settings, uuid: uuid)
        let instance = DataSourceInstance(id: uuid, dataSource: dataSource)
        sources.append(instance)
    }

    func add(_ dataSource: DataSourceWrapper) {
        self.add(type: dataSource.id)
    }

    func remove(instance: DataSourceInstance) {
        self.sources.removeAll { $0 == instance }
    }

    func save() {
        
    }

    func fetch() {
        let promises = sources.map { $0.fetch() }
        let zip = promises.dropFirst().reduce(into: AnyPublisher(promises[0].map { [$0] }) ) {
            res, just in
            res = res.zip(just) {
                i1, i2 -> [[DataItemBase]] in
                return i1 + [i2]
            }.eraseToAnyPublisher()
        }
        cancellable = zip
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("complete")
                case .failure(let error):
                    self.delegate?.dataSourceController(self, didFailWithError: error)
                }
            } receiveValue: { result in
                print("result = \(result)")
                let items = result.reduce([], +)
                self.delegate?.dataSourceController(self, didUpdateData: items)
            }
    }
}

extension DataSourceInstance {

    func fetch() -> Future<[DataItemBase], Error> {
        Future { promise in
            DispatchQueue.global().async {
                self.dataSource.fetch(uuid: id) { _, items, error in
                    if let error = error {
                        promise(.failure(error))
                    }
                    promise(.success(items ?? []))
                }
            }
        }
    }

}
