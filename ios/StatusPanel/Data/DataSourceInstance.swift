// Copyright (c) 2018-2022 Jason Morley, Tom Sutcliffe
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

    let details: Details
    let dataSource: AnyDataSource

    init(id: UUID, dataSource: AnyDataSource) {
        self.details = Details(id: id, type: dataSource.id)
        self.dataSource = dataSource
    }

    func fetch(completion: @escaping ([DataItemBase]?, Error?) -> Void) {
        DispatchQueue.global().async {
            self.dataSource.data(for: id, completion: completion)
        }
    }

}
