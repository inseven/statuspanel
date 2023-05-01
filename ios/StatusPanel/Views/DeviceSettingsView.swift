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

    class Model: ObservableObject {

        private let config: Config
        private let device: Device

        @MainActor @Published var settings: DeviceSettings {
            didSet {
                do {
                    try config.save(settings: settings, deviceId: device.id)
                } catch {
                    self.error = error
                }
            }
        }

        @Published var error: Error?

        @MainActor init(config: Config, device: Device) {
            self.config = config
            self.device = device
            do {
                self.settings = try config.settings(forDevice: device.id)
            } catch {
                self.settings = DeviceSettings(deviceId: device.id)
                self.error = error
            }
        }

    }

    enum SheetType: Identifiable {

        public var id: Self { self }

        case add
    }

    @ObservedObject var config: Config
    @ObservedObject var dataSourceController: DataSourceController
    var device: Device

    @StateObject var model: Model
    @State var sheet: SheetType? = nil
    @State var error: Error? = nil

    init(config: Config, dataSourceController: DataSourceController, device: Device) {
        self.config = config
        self.dataSourceController = dataSourceController
        self.device = device
        _model = StateObject(wrappedValue: Model(config: config, device: device))
    }

    var body: some View {
        Form {
            Section {
                TextField(device.kind.description, text: $model.settings.name)
            }
            Section("Layout") {
                ForEach(dataSourceController.instances) { dataSourceInstance in
                    NavigationLink {
                        try! dataSourceInstance.view(config: config)
                    } label: {
                        DataSourceInstanceRow(config: config, dataSourceInstance: dataSourceInstance)
                    }
                }
                .onDelete { indexSet in
                    do {
                        try dataSourceController.removeInstances(atOffsets: indexSet)
                    } catch {
                        self.error = error
                    }
                }
                .onMove { source, destination in
                    do {
                        try dataSourceController.moveInstances(fromOffsets: source, toOffset: destination)
                    } catch {
                        self.error = error
                    }
                }
            }
            Section("Fonts") {
                FontPicker("Title", selection: $model.settings.titleFont)
                FontPicker("Body", selection: $model.settings.bodyFont)
            }
            Section("Display") {
                Toggle("Use Two Columns", isOn: $model.settings.displayTwoColumns)
                Toggle("Show Icons", isOn: $model.settings.showIcons)
                Picker("Dark Mode", selection: $model.settings.darkMode) {
                    Text(Localized(Config.DarkMode.off))
                        .tag(Config.DarkMode.off)
                    Text(Localized(Config.DarkMode.on))
                        .tag(Config.DarkMode.on)
                    Text(Localized(Config.DarkMode.system))
                        .tag(Config.DarkMode.system)
                }
                Picker("Maximum Lines Per Item", selection: $model.settings.maxLines) {
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
                    PrivacyModeView(config: config, model: model)
                        .edgesIgnoringSafeArea(.all)
                        .navigationTitle(LocalizedString("privacy_mode_title"))
                } label: {
                    LabeledContent("Privacy Mode", value: Localized(model.settings.privacyMode))
                }
            }
            Section("Schedule") {
                DatePicker("Device Update Time", selection: $model.settings.updateTime, displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
            Section("Details") {
                LabeledContent("Type", value: device.kind.description)
                LabeledContent("Identifier", value: device.id)
            }
        }
        .alert(isPresented: $error.mappedToBool()) {
            Alert(error: error)
        }
        .navigationTitle("Device Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sheet = .add
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add:
                AddDataSourceView(config: config, dataSourceController: dataSourceController)
            }
        }
    }

}
