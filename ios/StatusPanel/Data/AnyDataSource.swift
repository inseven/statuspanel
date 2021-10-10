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
import UIKit

/// Type erasing wrapper for `DataSource`
class AnyDataSource: Identifiable {

    private var idProxy: (() -> DataSourceType)! = nil
    private var nameProxy: (() -> String)! = nil
    private var configurableProxy: (() -> Bool)! = nil
    private var dataProxy: ((UUID, @escaping ([DataItemBase]?, Error?) -> Void) -> Void)! = nil
    private var summaryProxy: ((UUID) throws -> String?)! = nil
    private var settingsViewControllerProxy: ((UUID) throws -> UIViewController?)! = nil
    private var validateSettingsProxy: ((DataSourceSettings) -> Bool)! = nil

    var id: DataSourceType {
        return idProxy()
    }

    var name: String {
        return nameProxy()
    }

    var configurable: Bool {
        return configurableProxy()
    }

    func data(for instanceId: UUID, completion: @escaping ([DataItemBase]?, Error?) -> Void) {
        return dataProxy(instanceId, completion)
    }

    func summary(for instanceId: UUID) throws -> String? {
        return try summaryProxy(instanceId)
    }

    func settingsViewController(for instanceId: UUID) throws -> UIViewController? {
        return try settingsViewControllerProxy(instanceId)
    }

    func validate(settings: DataSourceSettings) -> Bool {
        return validateSettingsProxy(settings)
    }

    init<T: DataSource>(_ dataSource: T) {
        idProxy = {
            return dataSource.id
        }
        configurableProxy = {
            return dataSource.configurable
        }
        dataProxy = { instanceId, completion in
            do {
                let settings = try dataSource.settings(for: instanceId)
                dataSource.data(settings: settings) { data, error in
                    if let error = error {
                        completion(nil, error)
                        return
                    }
                    completion(data, nil)
                }
            } catch {
                completion(nil, error)
                return
            }
        }
        nameProxy = {
            return dataSource.name
        }
        summaryProxy = { instanceId in
            let settings = try dataSource.settings(for: instanceId)
            return dataSource.summary(settings: settings)
        }
        settingsViewControllerProxy = { instanceId in
            let settings = try dataSource.settings(for: instanceId)
            let store = DataSourceSettingsStore<T.Settings>(config: Config(), uuid: instanceId)
            let viewController = dataSource.settingsViewController(store: store, settings: settings)
            viewController?.navigationItem.title = dataSource.name
            return viewController
        }
        validateSettingsProxy = { settings in
            return type(of: settings) == type(of: dataSource).Settings
        }

    }

}

extension DataSource {

    func anyDataSource() -> AnyDataSource {
        return AnyDataSource(self)
    }

}
