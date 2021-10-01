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

struct SourceManifestation: Identifiable {

    let id = UUID()
    let dataSource: GenericDataSource

    init<T: DataSource>(_ source: T) {
        self.dataSource = source.wrapped()
    }

}

enum SourceType {

    case calendar
    case dummy
    case nationalRail
    case calendarHeader
    case transportForLondon

}

protocol DataSourceControllerDelegate: AnyObject {
    // Always called in context of main thread
    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItemBase])
    func dataSourceController(_ dataSourceController: DataSourceController, didFailWithError error: Error)
}

class DataSourceController {

    var cancellable: Cancellable?

    weak var delegate: DataSourceControllerDelegate?
    var sources: [SourceManifestation] = []

    var factories: [SourceType: GenericDataSource] = [:]

    init() {

        factories = [
            .calendar: CalendarHeaderSource(defaults: CalendarHeaderSource.Settings(),
                                            flags: []).wrapped()
        ]

        let configuration = try! Bundle.main.configuration()
        add(dataSource: CalendarHeaderSource(defaults: CalendarHeaderSource.Settings(format: .variable(long: "yMMMMdEEE",
                                                                                                       short: "yMMMMdEEEE")),
                                             flags: [.header, .spansColumns]))
        add(dataSource: TFLDataSource(configuration: configuration))
        add(dataSource: NationalRailDataSource(configuration: configuration))
        add(dataSource: CalendarSource())
#if DEBUG
        add(dataSource: DummyDataSource())
#endif
        add(dataSource: CalendarSource(dayOffset: 1, header: "Tomorrow:"))
#if DEBUG
        add(dataSource: DummyDataSource())
#endif
    }

    fileprivate func add<T: DataSource>(dataSource: T) {
        sources.append(SourceManifestation(dataSource))
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

extension SourceManifestation {

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
