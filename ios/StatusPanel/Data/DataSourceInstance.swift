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

import Foundation
import SwiftUI

struct DataSourceInstance: Identifiable, Equatable {

    struct Details: Codable, Identifiable {

        enum CodingKeys: String, CodingKey {
            case id = "identifier"
            case type = "type"
        }

        var id: UUID
        var type: DataSourceType

    }

    static func == (lhs: DataSourceInstance, rhs: DataSourceInstance) -> Bool {
        return lhs.id == rhs.id
    }

    var id: UUID { details.id }

    let config: Config
    let details: Details
    let dataSource: AnyDataSource
    let model: AnyDataSourceModel?
    let settingsView: AnyView
    let settingsItem: AnyView

    init(config: Config, id: UUID, dataSource: AnyDataSource) {
        self.config = config
        self.details = Details(id: id, type: dataSource.id)
        self.dataSource = dataSource

        do {
            let views = try dataSource.views(config: config, instanceId: id)
            self.model = views.model
            self.settingsView = views.settingsView
            self.settingsItem = views.settingsItem
        } catch {
            self.model = nil
            self.settingsView = AnyView(Text(String(describing: error)))
            self.settingsItem = AnyView(Text(String(describing: error)))
        }
    }

    func fetch(config: Config, completion: @escaping ([DataItemBase]?, Error?) -> Void) {
        DispatchQueue.global().async {
            self.dataSource.data(config: config, instanceId: id, completion: completion)
        }
    }

}
