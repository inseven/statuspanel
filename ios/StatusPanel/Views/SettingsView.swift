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

struct SettingsView: View {

    enum SheetType: Identifiable {

        var id: Self { self }

        case about
    }

    @Environment(\.dismiss) var dismiss

    @ObservedObject var config: Config
    var dataSourceController: DataSourceController

    @State var sheet: SheetType? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Devices") {
                    if !config.devices.isEmpty {
                        ForEach(config.devices) { device in
                            NavigationLink {
                                DeviceSettingsView(config: config,
                                                   dataSourceController: dataSourceController,
                                                   device: device)
                            } label: {
                                VStack(alignment: .leading) {
                                    if let deviceSettings = try? config.settings(forDevice: device.id),
                                       !deviceSettings.name.isEmpty {
                                        Text(deviceSettings.name)
                                    } else {
                                        Text(Localized(device.kind))
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No Devices")
                            .foregroundColor(.secondary)
                    }
                }
                Section("Status") {
                    LabeledContent(LocalizedString("settings_last_background_update_label")) {
                        if let lastUpdate = config.lastBackgroundUpdate {
                            Text(lastUpdate, style: .time)
                        } else {
                            Text(LocalizedString("settings_last_background_update_value_never"))
                        }
                    }
                }
                Section("Debug") {
                    Toggle("Show Debug Information", isOn: $config.showDebugInformation)
                }
                Button("About StatusPanel...") {
                    sheet = .about
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .about:
                    AboutView()
                }
            }
        }
    }

}
