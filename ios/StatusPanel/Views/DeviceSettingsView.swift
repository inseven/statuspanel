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
import SwiftUI

struct DeviceSettingsView: View {

    @Environment(\.dismiss) var dismiss

    @ObservedObject var config: Config
    @ObservedObject var deviceModel: DeviceModel

    @State var error: Error? = nil

    init(config: Config, deviceModel: DeviceModel) {
        self.config = config
        self.deviceModel = deviceModel
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField(Localized(deviceModel.device.kind), text: $deviceModel.deviceSettings.name)
            }
            Section("Fonts") {
                FontPicker("Title", selection: $deviceModel.deviceSettings.titleFont)
                FontPicker("Body", selection: $deviceModel.deviceSettings.bodyFont)
            }
            Section("Display") {
                Toggle("Use Two Columns", isOn: $deviceModel.deviceSettings.displayTwoColumns)
                Toggle("Show Icons", isOn: $deviceModel.deviceSettings.showIcons)
                Picker("Dark Mode", selection: $deviceModel.deviceSettings.darkMode) {
                    Text(Localized(Config.DarkMode.off))
                        .tag(Config.DarkMode.off)
                    Text(Localized(Config.DarkMode.on))
                        .tag(Config.DarkMode.on)
                    Text(Localized(Config.DarkMode.system))
                        .tag(Config.DarkMode.system)
                }
                Picker("Maximum Lines Per Item", selection: $deviceModel.deviceSettings.maxLines) {
                    Text("1")
                        .tag(1)
                    Text("2")
                        .tag(2)
                    Text("3")
                        .tag(3)
                    Text("4")
                        .tag(4)
                    Text(LocalizedString("maximum_lines_unlimited_label"))
                        .tag(0)
                }
                NavigationLink {
                    PrivacyModeView(config: config, deviceModel: deviceModel)
                        .edgesIgnoringSafeArea(.all)
                        .navigationTitle(LocalizedString("privacy_mode_title"))
                } label: {
                    LabeledContent("Privacy Mode", value: Localized(deviceModel.deviceSettings.privacyMode))
                }
            }
            Section("Schedule") {
                DatePicker("Device Update Time",
                           selection: $deviceModel.deviceSettings.updateTime,
                           displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
        }
        .presents($error)
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

}
