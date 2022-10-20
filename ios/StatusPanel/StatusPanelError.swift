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

enum StatusPanelError: Error {

    case missingConfiguration
    case invalidResponse
    case invalidUrl
    case invalidDate
    case corruptSettings
    case unknownDataSource(DataSourceType)
    case internalInconsistency
    case incorrectSettingsType
    case invalidImage

}

extension StatusPanelError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return LocalizedString("error_missing_configuration")
        case .invalidResponse:
            return LocalizedString("error_invalid_response")
        case .invalidUrl:
            return LocalizedString("error_invalid_url")
        case .invalidDate:
            return LocalizedString("error_invalid_date")
        case .corruptSettings:
            return LocalizedString("error_corrupt_settings")
        case .unknownDataSource(let dataSource):
            return String(format: LocalizedString("error_unknown_data_source"), dataSource.rawValue)
        case .internalInconsistency:
            return LocalizedString("error_internal_inconsistency")
        case .incorrectSettingsType:
            return LocalizedString("error_incorrect_settings_type")
        case .invalidImage:
            return LocalizedString("error_invalid_image")
        }
    }

}
