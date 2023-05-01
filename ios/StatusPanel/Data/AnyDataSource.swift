// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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
import SwiftUI

/// Type erasing wrapper for `DataSource`
class AnyDataSource: Identifiable {

    private var idProxy: (() -> DataSourceType)! = nil
    private var nameProxy: (() -> String)! = nil
    private var imageProxy: (() -> UIImage)! = nil
    private var configurableProxy: (() -> Bool)! = nil
    private var dataProxy: ((Config, UUID, @escaping ([DataItemBase]?, Error?) -> Void) -> Void)! = nil
    private var summaryProxy: ((Config, UUID) throws -> String?)! = nil
    private var settingsViewProxy: ((Config, UUID) throws -> AnyView)! = nil
    private var validateSettingsProxy: ((DataSourceSettings) -> Bool)! = nil

    var id: DataSourceType {
        return idProxy()
    }

    var name: String {
        return nameProxy()
    }

    var image: UIImage {
        return imageProxy()
    }

    var configurable: Bool {
        return configurableProxy()
    }

    func data(config: Config, instanceId: UUID, completion: @escaping ([DataItemBase]?, Error?) -> Void) {
        return dataProxy(config, instanceId, completion)
    }

    func summary(config: Config, instanceId: UUID) throws -> String? {
        return try summaryProxy(config, instanceId)
    }

    func settingsView(config: Config, instanceId: UUID) throws -> AnyView {
        return try settingsViewProxy(config, instanceId)
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
        dataProxy = { config, instanceId, completion in
            do {
                let settings = try dataSource.settings(config: config, instanceId: instanceId)
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
        imageProxy = {
            return dataSource.image
        }
        summaryProxy = { config, instanceId in
            let settings = try dataSource.settings(config: config, instanceId: instanceId)
            return dataSource.summary(settings: settings)
        }
        settingsViewProxy = { config, instanceId in
            let settings = try dataSource.settings(config: config, instanceId: instanceId)
            let store = DataSourceSettingsStore<T.Settings>(config: config, uuid: instanceId)
            let view = dataSource
                .settingsView(store: store, settings: settings)
                .navigationTitle(dataSource.name)
            return AnyView(view)
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
