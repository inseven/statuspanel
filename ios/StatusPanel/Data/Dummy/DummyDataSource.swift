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

import Foundation
import SwiftUI
import UIKit

final class DummyDataSource : DataSource {

    struct Settings: DataSourceSettings, Equatable {
        var enabled: Bool = false
    }

    struct SettingsView: View {

        var store: DataSourceSettingsStore<DummyDataSource.Settings>
        @State var settings: DummyDataSource.Settings
        @State var error: Error? = nil

        var body: some View {
            Form {
                Toggle("Enabled", isOn: $settings.enabled)
            }
            .alert(isPresented: $error.mappedToBool()) {
                Alert(error: error)
            }
            .onChange(of: settings) { newValue in
                do {
                    try store.save(settings: newValue)
                } catch {
                    self.error = error
                }
            }
        }

    }

    let id: DataSourceType = .dummy
    let name = "Dummy Data"
    let image = UIImage(systemName: "text.alignleft", withConfiguration: UIImage.SymbolConfiguration(scale: .large))!
    let configurable = true

    var defaults: Settings {
        return Settings()
    }

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {
        var data: [DataItemBase] = []
        if settings.enabled {
            var specialChars: [String] = []
            let images = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "fonts/font6x10") ?? []
            for imgName in images.map({$0.lastPathComponent}).sorted() {
                let parts = StringUtils.regex(imgName,
                                              pattern: #"U\+([0-9A-Fa-f]+)(?:_U\+([0-9A-Fa-f]+))*(?:@[2-4])?\.png"#)
                if parts.count == 0 {
                    continue
                }
                var scalars: [UnicodeScalar] = []
                for part in parts {
                    if let num = UInt32(part, radix: 16) {
                        if let scalar = UnicodeScalar(num) {
                            scalars.append(scalar)
                        }
                    }
                }
                if scalars.count != parts.count {
                    continue // Some weirdly formatted img name?
                }
                let str = String(String.UnicodeScalarView(scalars))
                specialChars.append(str)
            }
            let specialCharsStr = specialChars.joined(separator: "")
            let specialCharsItem = CalendarItem(icon: "🗓",
                                                title: specialCharsStr,
                                                location: specialCharsStr,
                                                accentColor: UIColor.red)
            let dummyData: [DataItemBase] = [
                CalendarItem(time: "06:00",
                             title: "Something that has really long text that needs to wrap. Like, really really long!",
                             location: "A place that is also really really lengthy",
                             accentColor: UIColor.red),
                DataItem(text: "Northern line: part suspended", flags: [.warning]),
                DataItem(text: "07:44 to CBG: Cancelled", flags: [.warning]),
                CalendarItem(time: "09:40",
                             title: "Some text wot is multiline",
                             location: nil,
                             accentColor: UIColor.red),
            ]
            data.append(contentsOf: dummyData)
            if Config().showIcons {
                data.append(specialCharsItem)
            }
        }
        completion(data, nil)
    }

    func summary(settings: Settings) -> String? {
        return settings.enabled ? "Enabled" : "Disabled"
    }

    func settingsViewController(store: Store, settings: Settings) -> UIViewController? {
        return UIHostingController(rootView: SettingsView(store: store, settings: settings))
    }

}
