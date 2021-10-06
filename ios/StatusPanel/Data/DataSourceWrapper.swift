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
import SwiftUI
import UIKit

/// Type erasing wrapper for `DataSource`
class DataSourceWrapper: Identifiable {

    fileprivate var idProxy: (() -> DataSourceType)! = nil
    fileprivate var nameProxy: (() -> String)! = nil
    fileprivate var configurableProxy: (() -> Bool)! = nil
    fileprivate var fetchProxy: ((UUID, @escaping (DataSourceWrapper, [DataItemBase]?, Error?) -> Void) -> Void)! = nil
    fileprivate var summaryProxy: ((UUID) throws -> String?)! = nil
    fileprivate var settingsViewControllerProxy: ((UUID) throws -> UIViewController?)! = nil
    fileprivate var settingsViewProxy: ((UUID) throws -> UIViewController)! = nil
    fileprivate var validateSettingsProxy: ((DataSourceSettings) -> Bool)! = nil

    var id: DataSourceType { idProxy() }
    var name: String { nameProxy() }
    var configurable: Bool { configurableProxy() }
    func fetch(uuid: UUID, completion: @escaping (DataSourceWrapper, [DataItemBase]?, Error?) -> Void) { fetchProxy(uuid, completion) }
    func summary(uuid: UUID) throws -> String? { try summaryProxy(uuid) }
    func settingsViewController(uuid: UUID) throws -> UIViewController? { try settingsViewControllerProxy(uuid) }
    func settingsView(uuid: UUID) throws -> UIViewController { try settingsViewProxy(uuid) }
    func validate(settings: DataSourceSettings) -> Bool { validateSettingsProxy(settings) }

    init<T: DataSource>(_ dataSource: T) {
        idProxy = { dataSource.id }
        configurableProxy = { dataSource.configurable }
        fetchProxy = { uuid, completion in
            do {
                let settings = try dataSource.settings(uuid: uuid)
                dataSource.data(settings: settings) { data, error in
                    if let error = error {
                        completion(self, nil, error)
                        return
                    }
                    completion(self, data, nil)
                }
            } catch {
                completion(self, [], error)
                return
            }
        }
        nameProxy = { dataSource.name }
        summaryProxy = { uuid in
            let settings = try dataSource.settings(uuid: uuid)
            return dataSource.summary(settings: settings)
        }
        settingsViewControllerProxy = { uuid in
            let settings = try dataSource.settings(uuid: uuid)
            let wrapper = SettingsStore<T.Settings>(uuid: uuid)
            let viewController = dataSource.settingsViewController(store: wrapper, settings: settings)
            return viewController
        }
        settingsViewProxy = { uuid in
            let settings = try dataSource.settings(uuid: uuid)
            let wrapper = SettingsStore<T.Settings>(uuid: uuid)
            let viewController = UIHostingController(rootView: dataSource.settingsView(store: wrapper,
                                                                                       settings: settings))
            viewController.navigationItem.title = dataSource.name
            return viewController
        }
        validateSettingsProxy = { settings in
            type(of: settings) == type(of: dataSource).Settings
        }

    }

}

extension DataSource {

    func wrapped() -> DataSourceWrapper {
        DataSourceWrapper(self)
    }

}
