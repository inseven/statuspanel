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
import UIKit

import Sodium

struct Device: Identifiable, Equatable, Hashable {

    enum Kind: String, CaseIterable, Identifiable {

        static let demoDevices: [Kind] = [
            .pimoroniInkyImpression4,
            .einkV1,
            .featherTft
        ]

        var id: Self { self }

        case einkV1 = "0"
        case featherTft = "1"
        case pimoroniInkyImpression4 = "2"
        case pimoroniInkyImpression4_rle = "3"

        var description: String {
            switch self {
            case .einkV1:
                return "eInk Version 1"
            case .featherTft:
                return "Feather TFT"
            case .pimoroniInkyImpression4:
                return "Pimoroni Inky Impression 4 (PNG)"
            case .pimoroniInkyImpression4_rle:
                return "Pimoroni Inky Impression 4 (RLE)"
            }
        }
    }

    var kind: Kind
    var id: String
    var publicKey: String

    var size: CGSize {
        switch kind {
        case .einkV1:
            return CGSize(width: 640, height: 384)
        case .featherTft:
            return CGSize(width: 240, height: 135)
        case .pimoroniInkyImpression4, .pimoroniInkyImpression4_rle:
            return CGSize(width: 640, height: 400)
        }
    }

    var isFullColor: Bool {
        switch kind {
        case .einkV1:
            return false
        case .featherTft:
            return true
        case .pimoroniInkyImpression4:
            return true
        case .pimoroniInkyImpression4_rle:
            return false // Well, it is kinda, but...
        }
    }

    var supportsTwoColumns: Bool {
        return size.width < 500
    }

    var statusBarHeight: CGFloat {
        switch kind {
        case .einkV1:
            return 20
        case .featherTft:
            return 0
        case .pimoroniInkyImpression4:
            return 0
        case .pimoroniInkyImpression4_rle:
            return 20
        }
    }

    var encoding: Panel.Encoding {
        switch kind {
        case .einkV1:
            return .rle
        case .featherTft:
            return .png
        case .pimoroniInkyImpression4:
            return .png
        case .pimoroniInkyImpression4_rle:
            return .rle
        }
    }

    var renderer: Renderer {
        switch kind {
        case .einkV1:
            return PixelRenderer()
        case .featherTft:
            return PixelRenderer()
        case .pimoroniInkyImpression4:
            return PixelRenderer()
        case .pimoroniInkyImpression4_rle:
            return PixelRenderer()
        }
    }

    init(kind: Kind, id: String, publicKey: String) {
        self.kind = kind
        self.id = id
        self.publicKey = publicKey
    }

    init(kind: Kind = .einkV1) {
        self.kind = kind
        id = UUID().uuidString
        let sodium = Sodium()
        let keyPair = sodium.box.keyPair()!
        publicKey = sodium.utils.bin2base64(keyPair.publicKey, variant: .ORIGINAL)!
    }

    func blankImage() -> UIImage {
        return UIImage.blankImage(size: size, scale: 1.0)
    }

    func defaultSettings() -> DeviceSettings {
        var settings = DeviceSettings(deviceId: self.id)
        switch kind {
        case .einkV1:
            break
        case .featherTft:
            settings.titleFont = Fonts.FontName.unifont16
            settings.bodyFont = Fonts.FontName.unifont16
        case .pimoroniInkyImpression4, .pimoroniInkyImpression4_rle:
            settings.titleFont = Fonts.FontName.chiKareGo2
            settings.bodyFont = Fonts.FontName.unifont32
            settings.displayTwoColumns = false
        }
        return settings
    }

    func defaultDataSourceSettings(calendars: [String]) -> [AnyDataSourceSettings] {
        switch kind {
        case .einkV1:
            return [
                CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                              shortFormat: "yMMMMdEEE",
                                              offset: 0,
                                              flags: [.header, .spansColumns]).anyDataSourceSettings(),
                WeatherDataSource.Settings(flags: [],
                                           address: "Bletchley Park, Sherwood Drive, Bletchley, Milton Keynes, MK3 6EB",
                                           showLocation: true).anyDataSourceSettings(),
                CalendarDataSource.Settings(showLocations: true,
                                            showUrls: false,
                                            offset: 0,
                                            activeCalendars: Set(calendars)).anyDataSourceSettings(),
                TextDataSource.Settings(flags: [.prefersNewSection],
                                        text: "Tomorrow:").anyDataSourceSettings(),
                CalendarDataSource.Settings(showLocations: true,
                                            showUrls: false,
                                            offset: 1,
                                            activeCalendars: Set(calendars)).anyDataSourceSettings(),
            ]
        case .featherTft:
            return [
                CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                              shortFormat: "yMMMMdEEE",
                                              offset: 0,
                                              flags: [.header, .spansColumns]).anyDataSourceSettings(),
                WeatherDataSource.Settings(flags: [],
                                           address: "Bletchley Park, Sherwood Drive, Bletchley, Milton Keynes, MK3 6EB",
                                           showLocation: true).anyDataSourceSettings(),
                CalendarDataSource.Settings(showLocations: true,
                                            showUrls: false,
                                            offset: 0,
                                            activeCalendars: Set(calendars)).anyDataSourceSettings(),
            ]
        case .pimoroniInkyImpression4, .pimoroniInkyImpression4_rle:
            return [
                CalendarHeaderSource.Settings(longFormat: "yMMMMdEEEE",
                                              shortFormat: "yMMMMdEEE",
                                              offset: 0,
                                              flags: [.header, .spansColumns]).anyDataSourceSettings(),
                WeatherDataSource.Settings(flags: [],
                                           address: "Bletchley Park, Sherwood Drive, Bletchley, Milton Keynes, MK3 6EB",
                                           showLocation: true).anyDataSourceSettings(),
                ZenQuotesDataSource.Settings(flags: [], mode: .today).anyDataSourceSettings(),
                CalendarDataSource.Settings(showLocations: true,
                                            showUrls: false,
                                            offset: 0,
                                            activeCalendars: Set(calendars)).anyDataSourceSettings(),
            ]
        }
    }

}
