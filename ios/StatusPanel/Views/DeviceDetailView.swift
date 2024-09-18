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

    @Environment(\.dismiss) var dismiss

    @ObservedObject var config: Config
    @ObservedObject var dataSourceController: DataSourceController
    @ObservedObject var deviceModel: DeviceModel

    @State var editMode: EditMode = .inactive
    @State var sheet: SheetType? = nil

    init(config: Config, dataSourceController: DataSourceController, deviceModel: DeviceModel) {
        self.config = config
        self.dataSourceController = dataSourceController
        self.deviceModel = deviceModel
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
            Section {
                Button("Add Data Source") {
                    withAnimation {
                        editMode = .inactive
                    }
                    sheet = .add
                }
            }
            Section {
                Button("Device Settings") {
                    withAnimation {
                        editMode = .inactive
                    }
                    sheet = .settings
                }
            }
            if config.showDeveloperTools {
                Section {
                    LabeledContent("Identifier", value: deviceModel.device.id)
                    LabeledContent("Type", value: deviceModel.device.kind.description)
                    LabeledContent("Size") {
                        let size = deviceModel.device.size
                        Text(String(format: "%.0f x %.0f", size.width, size.height))
                    }
                }
                Section {
                    ShareLink(items: deviceModel.images) { image in
                        SharePreview(deviceModel.name, image: Image(uiImage: image))
                    } label: {
                        Text("Share Previews")
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    withAnimation {
                        editMode = .inactive
                    }
                    config.removeDevice(deviceModel.device)
                } label: {
                    Text("Delete Device")
                }
            }
        }
        .presents($deviceModel.error)
        .navigationTitle(deviceModel.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
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
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    self.sheet = nil
                                } label: {
                                    Text("Done")
                                        .fontWeight(.bold)
                                }
                            }
                        }
                }
            case .dataSourceSettings(let id):
                if let dataSourceInstance = deviceModel.dataSources.first(where: { $0.id == id }) {
                    NavigationView {
                        dataSourceInstance.settingsView
                            .toolbar {
                                ToolbarItem {
                                    Button {
                                        self.sheet = nil
                                    } label: {
                                        Text("Done")
                                            .fontWeight(.bold)
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
