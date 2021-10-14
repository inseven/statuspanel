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
    func dataSourceController(_ dataSourceController: DataSourceController, didFailWithError error: Error)
}

class DataSourceController {

    weak var delegate: DataSourceControllerDelegate?

    var sources: [AnyDataSource] = []
    var instances: [DataSourceInstance] = []
    var syncQueue = DispatchQueue(label: "DataSourceController.syncQueue")

    init() {

        let configuration = try! Bundle.main.configuration()
        sources = [
            CalendarSource().anyDataSource(),
            CalendarHeaderSource().anyDataSource(),
            DummyDataSource().anyDataSource(),
            NationalRailDataSource(configuration: configuration).anyDataSource(),
            TextDataSource().anyDataSource(),
            TFLDataSource(configuration: configuration).anyDataSource(),
            ZenQuotesDataSource().anyDataSource(),
        ]

        let config = Config()

        do {
            let instances = try Config().dataSources() ?? []
            do {
                for instance in instances {
                    try add(type: instance.type, uuid: instance.id)
                }
            } catch {
                print("Failed to load data source details with error \(error).")
            }
        } catch {
            print("Failed to load data sources with error \(error).")
        }

        // Restore the default configuration if there are none configured.
        if instances.isEmpty {
            do {
                try add(type: .calendarHeader,
                        settings: CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                                                shortFormat: "yMMMMdEEE",
                                                                offset: 0,
                                                                flags: [.header, .spansColumns]))
                try add(type: .transportForLondon,
                        settings: TFLDataSource.Settings(lines: config.activeTFLLines))
                try add(type: .nationalRail,
                        settings: NationalRailDataSource.Settings(from: config.trainRoute.from, to: config.trainRoute.to))
                try add(type: .calendar,
                        settings: CalendarSource.Settings(showLocations: config.showCalendarLocations,
                                                          showUrls: config.showUrlsInCalendarLocations,
                                                          offset: 0))
                try add(type: .text,
                        settings: TextDataSource.Settings(flags: [.prefersEmptyColumn],
                                                          text: "Tomorrow:"))
                try add(type: .calendar,
                        settings: CalendarSource.Settings(showLocations: config.showCalendarLocations,
                                                          showUrls: config.showUrlsInCalendarLocations,
                                                          offset: 1))
                try save()
            } catch {
                print("Failed to add default data sources with error \(error).")
            }
        }

    }

    private func add(type: DataSourceType, uuid: UUID = UUID()) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let dataSource = sources.first(where: { $0.id == type }) else {
            throw StatusPanelError.unknownDataSource(type)
        }
        instances.append(DataSourceInstance(id: uuid, dataSource: dataSource))
    }

    func add(_ details: DataSourceInstance.Details) throws {
        try self.add(type: details.type, uuid: details.id)
    }

    private func add<T: DataSourceSettings>(type: DataSourceType, settings: T) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let dataSource = sources.first(where: { $0.id == type }) else {
            throw StatusPanelError.unknownDataSource(type)
        }
        let uuid = UUID()
        if !dataSource.validate(settings: settings) {
            throw StatusPanelError.incorrectSettingsType
        }
        try Config().save(settings: settings, instanceId: uuid)
        instances.append(DataSourceInstance(id: uuid, dataSource: dataSource))
    }

    func add(_ dataSource: AnyDataSource) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        try self.add(type: dataSource.id)
    }

    func remove(instance: DataSourceInstance) {
        dispatchPrecondition(condition: .onQueue(.main))
        let index = instances.firstIndex(of: instance)!
        instances.remove(at: index)
    }

    func save() throws {
        dispatchPrecondition(condition: .onQueue(.main))
        try Config().set(dataSources: self.instances.map { $0.details })
    }

    func fetch() {
        dispatchPrecondition(condition: .onQueue(.main))
        let sources = Array(self.instances)  // Capture the ordered sources in case they change.
        syncQueue.async {

            let dispatchGroup = DispatchGroup()

            var results: [UUID: Result<[DataItemBase], Error>] = [:]  // Synchronized on syncQueue.
            for source in sources {
                dispatchGroup.enter()
                source.fetch { data, error in
                    self.syncQueue.async {
                        if let error = error {
                            results[source.id] = .failure(error)
                        } else if let data = data {
                            results[source.id] = .success(data)
                        } else {
                            results[source.id] = .failure(StatusPanelError.internalInconsistency)
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: self.syncQueue) {
                let orderedResults = sources.compactMap { results[$0.id] }
                let errors = orderedResults.compactMap { result -> Error? in
                    switch result {
                    case .success:
                        return nil
                    case .failure(let error):
                        return error
                    }
                }
                if let error = errors.first {
                    DispatchQueue.main.async {
                        self.delegate?.dataSourceController(self, didFailWithError: error)
                    }
                    return
                }
                let items = orderedResults.compactMap { result -> [DataItemBase]? in
                    switch result {
                    case .success(let items):
                        return items
                    case .failure:
                        return nil
                    }
                }.reduce([], +)
                DispatchQueue.main.async {
                    self.delegate?.dataSourceController(self, didUpdateData: items)
                }
            }
        }

    }

}
