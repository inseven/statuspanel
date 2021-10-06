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

protocol DataSourceSettings: Codable {

}

protocol DataSource: AnyObject, Identifiable {

    typealias Callback = ([DataItemBase], Error?) -> Void // TODO: Move this inline.
    typealias Store = SettingsStore<Settings>

    associatedtype Settings: DataSourceSettings
    associatedtype SettingsView: View = EmptyView

    var id: DataSourceType { get }

    var name: String { get }
    var configurable: Bool { get }

    var defaults: Settings { get }

    func data(settings: Settings, completion: @escaping Callback)

    func summary(settings: Settings) -> String?

    func settingsViewController(store: Store, settings: Settings) -> UIViewController?

    func settingsView(store: Store, settings: Settings) -> SettingsView

}

extension DataSource {

    // TODO: Check the thread safety (in the settings themselves?)
    func settings(uuid: UUID) throws -> Settings {
        var settings: Settings!
        do {
            settings = try Config().settings(uuid: uuid)
        } catch StatusPanelError.noSettings {
            settings = defaults
        }
        return settings
    }

}

class SettingsStore<T: DataSourceSettings> {

    var uuid: UUID

    init(uuid: UUID) {
        self.uuid = uuid
    }

    func save(settings: T) throws {
        try Config().save(settings: settings, uuid: uuid)
    }

}

struct DataItemFlags: OptionSet, Codable {

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
