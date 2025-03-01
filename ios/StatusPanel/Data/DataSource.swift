// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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
import SwiftUI

protocol DataSourceSettings: Codable {

    static var dataSourceType: DataSourceType { get }

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
