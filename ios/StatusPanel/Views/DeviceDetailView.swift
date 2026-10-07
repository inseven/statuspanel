// Copyright (c) 2018-2026 Jason Morley, Tom Sutcliffe
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

extension UIImage: @retroactive Identifiable {

    public var id: Int { self.hash }

}

struct DeviceDetailView: View {

    enum SheetType: Identifiable {

        public var id: String {
            switch self {
            case .add:
                return "add"
            case .settings:
                return "settings"
            case .dataSourceSettings(let id):
                return "dataSourceSettings-\(id.uuidString)"
            }
        }

        case add
        case settings
        case dataSourceSettings(UUID)
    }

    let applicationModel: ApplicationModel

    @Environment(\.dismiss) var dismiss

    @ObservedObject var config: Config
    @ObservedObject var dataSourceController: DataSourceController
    @ObservedObject var deviceModel: DeviceModel

    @State var editMode: EditMode = .inactive
    @State var sheet: SheetType? = nil

    init(applicationModel: ApplicationModel,
         config: Config,
         dataSourceController: DataSourceController,
         deviceModel: DeviceModel) {
        self.applicationModel = applicationModel
        self.config = config
        self.dataSourceController = dataSourceController
        self.deviceModel = deviceModel
    }

    func addDataSource() {
        withAnimation {
            editMode = .inactive
        }
        sheet = .add
    }

    func deleteDevice() {
        withAnimation {
            editMode = .inactive
        }
        applicationModel.removeDevice(deviceModel.device)
    }

    func showDeviceSettings() {
        withAnimation {
            editMode = .inactive
        }
        sheet = .settings
    }

    var body: some View {
        Form {
            Section {
                VStack {
                    TabView {
                        ForEach(deviceModel.images) { image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .border(.secondary)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(minHeight: 300)
                }
            }
            Section {
                if !deviceModel.dataSources.isEmpty {
                    ForEach(deviceModel.dataSources) { dataSourceInstance in
                        Button {
                            sheet = .dataSourceSettings(dataSourceInstance.id)
                        } label: {
                            dataSourceInstance.settingsItem
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { indexSet in
                        deviceModel.deviceSettings.dataSources.remove(atOffsets: indexSet)
                    }
                    .onMove { indexSet, offset in
                        deviceModel.deviceSettings.dataSources.move(fromOffsets: indexSet, toOffset: offset)
                    }
                } else {
                    Text("No Data Sources")
                        .foregroundColor(.secondary)
                }
            }
            if config.showDeveloperTools && editMode == .inactive {
                Section {
                    LabeledContent("Identifier", value: deviceModel.device.id)
                    LabeledContent("Type", value: deviceModel.device.kind.description)
                    LabeledContent("Size") {
                        let size = deviceModel.device.size
                        Text(String(format: "%.0f x %.0f", size.width, size.height))
                    }
                }
            }
        }
        .presents($deviceModel.error)
        .navigationTitle(deviceModel.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if editMode == .inactive {
                    Menu {
                        Button("Edit", systemImage: "checkmark.circle") {
                            withAnimation {
                                editMode = .active
                            }
                        }
                        Button("Add Data Source", systemImage: "plus.circle.fill") {
                            addDataSource()
                        }
                        Divider()
                        Button("Device Settings", systemImage: "gear") {
                            showDeviceSettings()
                        }
                        Divider()
                        ShareLink(items: deviceModel.images) { image in
                            SharePreview(deviceModel.name, image: Image(uiImage: image))
                        } label: {
                            Label("Share Previews", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button("Remove Device", systemImage: "trash", role: .destructive) {
                            deleteDevice()
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                } else {
                    Button("Done", systemImage: "checkmark", role: .prefersConfirm) {
                        withAnimation {
                            editMode = .inactive
                        }
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add:
                AddDataSourceView(config: config,
                                  dataSourceController: dataSourceController,
                                  dataSources: $deviceModel.deviceSettings.dataSources)
            case .settings:
                NavigationView {
                    DeviceSettingsView(config: config, deviceModel: deviceModel)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Done", systemImage: "checkmark") {
                                    self.sheet = nil
                                }
                            }
                        }
                }
            case .dataSourceSettings(let id):
                if let dataSourceInstance = deviceModel.dataSources.first(where: { $0.id == id }) {
                    NavigationView {
                        dataSourceInstance.settingsView
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Done", systemImage: "checkmark") {
                                        self.sheet = nil
                                    }
                                }
                            }
                    }
                } else {
                    Text("Failed to load view")
                }
            }
        }
    }

}
