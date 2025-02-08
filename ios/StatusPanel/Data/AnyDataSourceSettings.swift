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

class AnyDataSourceSettings: Encodable {

    private let dataSourceTypeProxy: (() -> DataSourceType)
    private let encodeProxy: ((Encoder) throws -> Void)

    var dataSourceType: DataSourceType {
        return dataSourceTypeProxy()
    }

    init<T: DataSourceSettings>(_ dataSourceSettings: T) {
        dataSourceTypeProxy = {
            return type(of: dataSourceSettings).dataSourceType
        }
        encodeProxy = { encoder in
            try dataSourceSettings.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeProxy(encoder)
    }

}

extension DataSourceSettings {

    func anyDataSourceSettings() -> AnyDataSourceSettings {
        return AnyDataSourceSettings(self)
    }

}
