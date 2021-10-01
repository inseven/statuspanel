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

    var identifier: SourceInstance { get }

    var defaults: Settings { get }

    func data(settings: Settings, completion: @escaping Callback)

    // Perhaps an instance name as well?

    // TODO: Inject the settings
    func summary() -> String?

    // TODO: Inject the settings
    // TODO: Nullable?
    func settingsViewController() -> UIViewController?

    func settingsView() -> SettingsView

}

extension DataSource {

    func wrapped() -> GenericDataSource {
        GenericDataSource(self)
    }

}

// TODO: Does this actually need to be a DataSource?
// TODO: Does this need to be Equatable?
// TODO: DataSourceWrapper / DataSourceProxy?
class GenericDataSource: Equatable {

    let id = UUID()

    fileprivate var nameProxy: (() -> String)! = nil
    fileprivate var configurableProxy: (() -> Bool)! = nil
    fileprivate var identifierProxy: (() -> SourceInstance)! = nil
    fileprivate var fetchProxy: ((@escaping (GenericDataSource, [DataItemBase]?, Error?) -> Void) -> Void)! = nil
    fileprivate var summaryProxy: (() -> String?)! = nil
    fileprivate var settingsViewControllerProxy: (() -> UIViewController?)! = nil
    fileprivate var settingsViewProxy: (() -> UIViewController)! = nil

    var name: String { nameProxy() }
    var configurable: Bool { configurableProxy() }
    var identifier: SourceInstance { identifierProxy() } // TODO: Do I even need this?
    func fetch(completion: @escaping (GenericDataSource, [DataItemBase]?, Error?) -> Void) { fetchProxy(completion) }
    func summary() -> String? { summaryProxy() }
    func settingsViewController() -> UIViewController? { settingsViewControllerProxy() }
    func settingsView() -> UIViewController { settingsViewProxy() }

    // TODO: This is probably wrong.
    static func == (lhs: GenericDataSource, rhs: GenericDataSource) -> Bool {
        lhs.id == rhs.id
    }

    init<T: DataSource>(_ dataSource: T) {
        identifierProxy = { dataSource.identifier }
        configurableProxy = { dataSource.configurable }
        fetchProxy = { completion in

            // Load the settings.
            // TODO: Do we need to check what thread this runs on?
            var settings: T.Settings!
            do {
                settings = try Config().settings(instance: dataSource.identifier)
            } catch StatusPanelError.noSettings {
                settings = dataSource.defaults
            } catch {
                completion(self, [], error)
                return
            }

            dataSource.data(settings: settings) { _, data, error in

                if let error = error {
                    completion(self, nil, error)
                    return
                }
                completion(self, data, nil)
            }
        }
        nameProxy = { dataSource.name }
        summaryProxy = dataSource.summary
        settingsViewControllerProxy = dataSource.settingsViewController
        settingsViewProxy = {
            let viewController = UIHostingController(rootView: dataSource.settingsView())
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
