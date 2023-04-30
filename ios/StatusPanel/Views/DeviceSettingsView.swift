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

struct DeviceSettingsView: View {

    // N.B. This model currently uses the global `Config` object. It's doing this to allow the new device UI to be built
    // out in advance of introducing per-device settings and associated data migrations. It's likely this model will be
    // serve as the starting-point for the device configuration.
    class Model: ObservableObject {

        let config = Config()

        @Published var displayTwoColumns: Bool {
            didSet {
                config.displayTwoColumns = displayTwoColumns
            }
        }

        @Published var showIcons: Bool {
            didSet {
                config.showIcons = showIcons
            }

        }

        @Published var darkMode: Config.DarkMode {
            didSet {
                config.darkMode = darkMode
            }
        }

        @Published var maxLines: Int {
            didSet {
                config.maxLines = maxLines
            }
        }

        @Published var privacyMode: Config.PrivacyMode {
            didSet {
                config.privacyMode = privacyMode
            }
        }

        init() {
            displayTwoColumns = config.displayTwoColumns
            showIcons = config.showIcons
            darkMode = config.darkMode
            maxLines = config.maxLines
            privacyMode = config.privacyMode
        }

    }

    @StateObject var model = Model()
    @State var isShowingPrivacy = false

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Use Two Columns", isOn: $model.displayTwoColumns)
                Toggle("Show Icons", isOn: $model.showIcons)
                Picker("Dark Mode", selection: $model.darkMode) {
                    Text(Localized(Config.DarkMode.off))
                        .tag(Config.DarkMode.off)
                    Text(Localized(Config.DarkMode.on))
                        .tag(Config.DarkMode.on)
                    Text(Localized(Config.DarkMode.system))
                        .tag(Config.DarkMode.system)
                }
                Picker("Maximum Lines Per Item", selection: $model.maxLines) {
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
                    PrivacyModeView(model: model)
                        .edgesIgnoringSafeArea(.all)
                        .navigationTitle(LocalizedString("privacy_mode_title"))
                } label: {
                    LabeledContent("Privacy Mode", value: Localized(model.privacyMode))
                }
            }

        }
        .navigationTitle("Device Settings")
    }

}
