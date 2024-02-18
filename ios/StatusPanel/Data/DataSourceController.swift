// Copyright (c) 2018-2024 Jason Morley, Tom Sutcliffe
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

import EventKit
import Foundation
import SwiftUI

class DataSourceController: ObservableObject {

    static let sources: [AnyDataSource] = {
        let configuration = try! Bundle.main.configuration()
        return [
            CalendarDataSource().anyDataSource(),
            CalendarHeaderSource().anyDataSource(),
            DummyDataSource().anyDataSource(),
            LastUpdateDataSource().anyDataSource(),
            TextDataSource().anyDataSource(),
            TFLDataSource(configuration: configuration).anyDataSource(),
            WeatherDataSource().anyDataSource(),
            ZenQuotesDataSource().anyDataSource(),
        ].sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    }()

    let config: Config
    var syncQueue = DispatchQueue(label: "DataSourceController.syncQueue")

    init(config: Config) {
        self.config = config
    }

    func dataSourceInstances(for dataSourceDetails: [DataSourceInstance.Details]) throws -> [DataSourceInstance] {
        return try dataSourceDetails.map { try dataSourceInstance(for: $0) }
    }

    func dataSourceInstance(for details: DataSourceInstance.Details) throws -> DataSourceInstance {
        guard let dataSource = Self.sources.first(where: { $0.id == details.type }) else {
            throw StatusPanelError.unknownDataSource(details.type)
        }
        return DataSourceInstance(config: config, id: details.id, dataSource: dataSource)
    }

    func fetch(details: [DataSourceInstance.Details]) async throws -> [DataItemBase] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.fetch(details: details) { items, error in
                    guard error == nil,
                          let items = items
                    else {
                        continuation.resume(with: .failure(error ?? StatusPanelError.internalInconsistency))
                        return
                    }
                    continuation.resume(with: .success(items))
                }
            }
        }
    }

    func fetch(details: [DataSourceInstance.Details], completion: @escaping ([DataItemBase]?, Error?) -> Void) {
        syncQueue.async {
            let dataSources: [DataSourceInstance]
            do {
                dataSources = try self.dataSourceInstances(for: details)
            } catch {
                completion(nil, error)
                return
            }

            let dispatchGroup = DispatchGroup()
            var results: [UUID: Result<[DataItemBase], Error>] = [:]  // Synchronized on syncQueue.
            for dataSource in dataSources {
                dispatchGroup.enter()
                dataSource.fetch(config: self.config) { data, error in
                    self.syncQueue.async {
                        if let error = error {
                            results[dataSource.id] = .failure(error)
                        } else if let data = data {
                            results[dataSource.id] = .success(data)
                        } else {
                            results[dataSource.id] = .failure(StatusPanelError.internalInconsistency)
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: self.syncQueue) {
                let orderedResults = dataSources.compactMap { results[$0.id] }
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
                        completion(nil, error)
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
                    completion(items, nil)
                }
            }
        }

    }

}
