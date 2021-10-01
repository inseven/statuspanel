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

// TODO: Any Protocol?

// TODO: The identifier shouldn't be used for equality at render time?

// TODO: This should expose an identifier?
protocol DataSource: AnyObject {

    var name: String { get }
    var configurable: Bool { get }

    associatedtype Settings: SettingsProtocol
    associatedtype SettingsView: View = EmptyView

    typealias Callback = (Self, [DataItemBase], Error?) -> Void
    typealias Store = (Settings) -> Void

//    var identifier: SourceInstance { get }

    var defaults: Settings { get }

    func data(settings: Settings, completion: @escaping Callback)

    // Perhaps an instance name as well?

    func summary(settings: Settings) -> String?

    // TODO: Inject the settings
    func settingsViewController() -> UIViewController?

    func settingsView(settings: Settings, store: @escaping Store) -> SettingsView

}

extension DataSource {

    func wrapped() -> GenericDataSource {
        GenericDataSource(self)
    }

}

extension DataSource {

    // TODO: Check the thread safety (in the settings themselves?)
    func settings(uuid: UUID) throws -> Settings {
        var settings: Settings!
        do {
            settings = try Config().settings(instance: .local(uuid: uuid))
        } catch StatusPanelError.noSettings {
            settings = defaults
        }
        return settings
    }

}

// TODO: DataSourceWrapper / DataSourceProxy?
class GenericDataSource {

    // TODO: Move the UUID onto here?

    fileprivate var nameProxy: (() -> String)! = nil
    fileprivate var configurableProxy: (() -> Bool)! = nil
    fileprivate var fetchProxy: ((UUID, @escaping (GenericDataSource, [DataItemBase]?, Error?) -> Void) -> Void)! = nil
    fileprivate var summaryProxy: ((UUID) throws -> String?)! = nil
    fileprivate var settingsViewControllerProxy: (() -> UIViewController?)! = nil
    fileprivate var settingsViewProxy: ((UUID) throws -> UIViewController)! = nil

    var name: String { nameProxy() }
    var configurable: Bool { configurableProxy() }
    func fetch(uuid: UUID, completion: @escaping (GenericDataSource, [DataItemBase]?, Error?) -> Void) { fetchProxy(uuid, completion) }
    func summary(uuid: UUID) throws -> String? { try summaryProxy(uuid) }
    func settingsViewController() -> UIViewController? { settingsViewControllerProxy() }
    func settingsView(uuid: UUID) throws -> UIViewController { try settingsViewProxy(uuid) }

    init<T: DataSource>(_ dataSource: T) {
        configurableProxy = { dataSource.configurable }
        fetchProxy = { uuid, completion in
            do {
                let settings = try dataSource.settings(uuid: uuid)
                dataSource.data(settings: settings) { _, data, error in
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
        settingsViewControllerProxy = dataSource.settingsViewController
        settingsViewProxy = { uuid in
            let settings = try dataSource.settings(uuid: uuid)
            let viewController = UIHostingController(rootView: dataSource.settingsView(settings: settings, store: { settings in
                try! Config().save(settings: settings, uuid: uuid)
            }))
            viewController.navigationItem.title = dataSource.name
            return viewController
        }

    }

}

struct DataItemFlags: OptionSet {

    let rawValue: Int

    static let warning = DataItemFlags(rawValue: 1 << 0)
    static let header = DataItemFlags(rawValue: 1 << 1)
    static let prefersEmptyColumn = DataItemFlags(rawValue: 1 << 2)
    static let spansColumns = DataItemFlags(rawValue: 1 << 3)
}

protocol DataItemBase : AnyObject {

    var icon: String? { get }
    var prefix: String { get }
    var flags: DataItemFlags { get }
    var subText: String? { get }

    func getText(checkFit: (String) -> Bool) -> String
}

extension DataItemBase {

    var iconAndPrefix: String {
        var elements: [String] = []
        if let icon = self.icon {
            elements.append(icon)
        }
        let prefix = self.prefix
        if !prefix.isEmpty {
            elements.append(prefix)
        }
        return elements.joined(separator: " ")
    }

}

class DataItem : Equatable, DataItemBase {

    let icon: String?
    let text: String
    let flags: DataItemFlags

    init(icon: String?, text: String, flags: DataItemFlags = []) {
        self.icon = icon
        self.text = text
        self.flags = flags
    }

    convenience init(text: String, flags: DataItemFlags = []) {
        self.init(icon: nil, text: text, flags: flags)
    }

    var prefix: String { "" }

    var subText: String? { nil }

    func getText(checkFit: (String) -> Bool) -> String {
        return text
    }

    static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.text == rhs.text && lhs.flags == rhs.flags
    }
}
