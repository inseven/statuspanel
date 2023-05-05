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

import Combine
import Foundation
import UIKit
import SwiftUI

protocol DataSourceSettings: Codable {

}

class AnyDataSourceModel {

    let subscribe: (@escaping () -> Void) -> AnyCancellable

    init<T: DataSourceSettings>(_ dataSourceModel: DataSourceModel<T>) {
        subscribe = { action in
            return dataSourceModel
                .objectWillChange
                .sink { _ in
                    action()
                }
        }
    }

}

class DataSourceModel<T: DataSourceSettings>: ObservableObject {

    let store: DataSourceSettingsStore<T>

    @Published var settings: T
    @Published var error: Error? = nil

    var cancellables: Set<AnyCancellable> = []

    init(store: DataSourceSettingsStore<T>, settings: T) {
        self.store = store
        self.settings = settings
    }

    func start() {
        $settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dataSourceSettings in
                guard let self else { return }
                do {
                    try self.store.save(settings: self.settings)
                } catch {
                    print("Failed to save data source settings with error \(error).")
                    self.error = error
                }
            }
            .store(in: &cancellables)
    }

}


protocol DataSource: AnyObject, Identifiable {

    typealias Model = DataSourceModel<Settings>
    typealias Store = DataSourceSettingsStore<Settings>

    associatedtype Settings: DataSourceSettings
    associatedtype SettingsView: View
    associatedtype SettingsItem: View

    static var id: DataSourceType { get }
    static var name: String { get }
    static var image: Image { get }

    var defaults: Settings { get }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void)

    func settingsView(model: Model) -> SettingsView

    func settingsItem(model: Model) -> SettingsItem

}

extension DataSource {

    func settings(config: Config, instanceId: UUID) throws -> Settings {
        guard let settings: Settings = try? config.settings(for: instanceId) else {
            return defaults
        }
        return settings
    }

}

struct DataItemFlags: OptionSet, Codable {

    enum Style {
        case title
        case body
    }

    let rawValue: Int

    static let warning = DataItemFlags(rawValue: 1 << 0)
    static let header = DataItemFlags(rawValue: 1 << 1)
    static let prefersNewSection = DataItemFlags(rawValue: 1 << 2)
    static let spansColumns = DataItemFlags(rawValue: 1 << 3)

    var labelStyle: LabelStyle {
        if contains(.header) {
            return .header
        }
        return .text
    }

    var style: Style {
        get {
            if contains(.header) {
                return .title
            }
            return .body
        }
        set {
            switch newValue {
            case .title:
                insert(.header)
            case .body:
                remove(.header)
            }
        }
    }
    
}

protocol DataItemBase : AnyObject {

    var icon: String? { get }
    var prefix: String { get }
    var flags: DataItemFlags { get }
    var subText: String? { get }
    var accentColor: UIColor? { get }

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
    let accentColor: UIColor?

    init(icon: String?, text: String, flags: DataItemFlags = [], accentColor: UIColor? = nil) {
        self.icon = icon
        self.text = text
        self.flags = flags
        self.accentColor = accentColor
    }

    convenience init(text: String, flags: DataItemFlags = []) {
        self.init(icon: nil, text: text, flags: flags)
    }

    var prefix: String {
        return ""
    }

    var subText: String? {
        nil
    }

    func getText(checkFit: (String) -> Bool) -> String {
        return text
    }

    static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.text == rhs.text && lhs.flags == rhs.flags
    }
}
