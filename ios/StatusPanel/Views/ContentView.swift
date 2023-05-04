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
import UIKit

struct ContentView: View {

    enum SheetType: Identifiable {
        var id: Self { return self }

        case settings
        case add
    }

    @ObservedObject var applicationModel: ApplicationModel

    let config: Config
    let dataSourceController: DataSourceController

    @State var sheet: SheetType? = nil

    init(applicationModel: ApplicationModel, config: Config, dataSourceController: DataSourceController) {
        self.applicationModel = applicationModel
        self.config = config
        self.dataSourceController = dataSourceController
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(applicationModel.deviceModels) { deviceModel in
                    Section {
                        DeviceView(deviceModel: deviceModel)
                    }
                }
            }
            .navigationTitle("StatusPanel")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        sheet = .settings
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            sheet = .add
                        } label: {
                            Label("Scan QR Code", systemImage: "qrcode")
                        }
                        Button {
                            guard let clipboard = UIPasteboard.general.string,
                               let url = URL(string: clipboard) else {
                                return
                            }
                            _ = AppDelegate.shared.application(UIApplication.shared, open: url, options: [:])
                        } label: {
                            Label("Add From Clipboard", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }

                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(config: config, dataSourceController: dataSourceController)
                case .add:
                    AddView()
                }
            }
        }
        .onAppear {
            applicationModel.start()
        }
    }

}