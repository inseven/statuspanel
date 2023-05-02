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

import SwiftUI

struct DeviceSettings: Codable {

    enum CodingKeys: String, CodingKey {
        case deviceId
        case name
        case displayTwoColumns
        case showIcons
        case darkMode
        case maxLines
        case privacyMode
        case updateTime
        case titleFont
        case bodyFont
        case dataSources
    }

    let deviceId: String
    var name: String = ""
    var displayTwoColumns: Bool = true
    var showIcons: Bool = true
    var darkMode: Config.DarkMode = .off
    var maxLines: Int = 0
    var privacyMode: Config.PrivacyMode = .redactLines
    var updateTime: Date = Date(timeIntervalSinceReferenceDate: (6 * 60 + 20) * 60)
    var titleFont: String = Fonts.FontName.chiKareGo2
    var bodyFont: String =  Fonts.FontName.unifont16
    var dataSources: [DataSourceInstance.Details] = []

    var displaysInDarkMode: Bool {
        switch darkMode {
        case .off:
            return false
        case .on:
            return true
        case .system:
            return UITraitCollection.current.userInterfaceStyle == UIUserInterfaceStyle.dark
        }
    }

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        name = try container.decode(String.self, forKey: .name)
        displayTwoColumns = try container.decode(Bool.self, forKey: .displayTwoColumns)
        showIcons = try container.decode(Bool.self, forKey: .showIcons)
        darkMode = try container.decode(Config.DarkMode.self, forKey: .darkMode)
        maxLines = try container.decode(Int.self, forKey: .maxLines)
        privacyMode = try container.decode(Config.PrivacyMode.self, forKey: .privacyMode)
        updateTime = Date(timeIntervalSinceReferenceDate: try container.decode(TimeInterval.self, forKey: .updateTime))
        titleFont = try container.decode(String.self, forKey: .titleFont)
        bodyFont = try container.decode(String.self, forKey: .bodyFont)
        dataSources = try container.decode([DataSourceInstance.Details].self, forKey: .dataSources)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(name, forKey: .name)
        try container.encode(displayTwoColumns, forKey: .displayTwoColumns)
        try container.encode(showIcons, forKey: .showIcons)
        try container.encode(darkMode, forKey: .darkMode)
        try container.encode(maxLines, forKey: .maxLines)
        try container.encode(privacyMode, forKey: .privacyMode)
        try container.encode(updateTime.timeIntervalSinceReferenceDate, forKey: .updateTime)
        try container.encode(titleFont, forKey: .titleFont)
        try container.encode(bodyFont, forKey: .bodyFont)
        try container.encode(dataSources, forKey: .dataSources)
    }

    // TODO: Extract privacy image generation and management to a separate utility #533
    //       https://github.com/inseven/statuspanel/issues/533

    func privacyImage() throws -> UIImage? {
        let url = try FileManager.default.documentsUrl().appendingPathComponent("privacy-image-\(deviceId).png")
        return UIImage(contentsOfFile: url.path)
    }

    func setPrivacyImage(_ image: UIImage?) throws {
        let fileManager = FileManager.default
        let url = try fileManager.documentsUrl().appendingPathComponent("privacy-image-\(deviceId).png")
        guard let image = image else {
            if fileManager.fileExists(at: url) {
                try fileManager.removeItem(at: url)
            }
            return
        }
        guard let data = image.pngData() else {
            throw StatusPanelError.invalidImage
        }
        try data.write(to: url, options: [.atomic])
    }

    // The wake time relative to start of day GMT. If waketime is 6*60*60 then this returns the offset from midnight GMT
    // to 0600 local time. It is always positive.
    func localUpdateTime() -> TimeInterval {
        var result = updateTime.timeIntervalSinceReferenceDate - TimeInterval(TimeZone.current.secondsFromGMT())
        if result < 0 {
            result += 24 * 60 * 60
        }
        return result
    }

}
