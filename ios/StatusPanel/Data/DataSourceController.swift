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
    var sources: [DataSource] = []
    var syncQueue = DispatchQueue(label: "DataSourceController.syncQueue")

    func add(dataSource: DataSource) {
        sources.append(dataSource)
    }

    func fetch() {
        dispatchPrecondition(condition: .onQueue(.main))
        let sources = Array(self.sources)  // Capture the ordered sources in case they change.
        syncQueue.async {

            let dispatchGroup = DispatchGroup()

            var results: [ObjectIdentifier: Result<[DataItemBase], Error>] = [:]  // Synchronized on queue.
            for source in sources {
                let identifier = ObjectIdentifier(source)
                dispatchGroup.enter()
                source.fetchData { data, error in
                    self.syncQueue.async {
                        if let error = error {
                            results[identifier] = .failure(error)
                        } else {
                            results[identifier] = .success(data)
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: self.syncQueue) {
                let orderedResults = sources.compactMap { results[ObjectIdentifier($0)] }
                let errors = orderedResults.compactMap { result -> Error? in
                    switch result {
                    case .success:
                        return nil
                    case .failure(let error):
                        return error
                    }
                }
                if let error = errors.first {
                    print("Failed to retrieve results with error \(error).")
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
