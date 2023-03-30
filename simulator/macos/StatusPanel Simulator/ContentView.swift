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

struct ContentView: View {

    @EnvironmentObject var applicationModel: ApplicationModel

    var body: some View {
        ScrollView {
            ForEach(applicationModel.devices) { deviceModel in
                HStack {
                    Spacer()
                    DeviceView(deviceModel: deviceModel)
                        .padding()
                    Spacer()
                }
            }
            .padding()
        }
        .textSelection(.enabled)
        .toolbar(id: "main") {
            ToolbarItem(id: "add") {
                Menu {
                    Button {
                        let identifier = DeviceConfiguration()
                        let model = DeviceModel(identifier: identifier)
                        applicationModel.devices.append(model)
                        model.start()
                    } label: {
                        Label("eInk Version 1", systemImage: "plus")
                    }
                    Button {
                        let identifier = DeviceConfiguration(kind: .featherTft)
                        let model = DeviceModel(identifier: identifier)
                        applicationModel.devices.append(model)
                        model.start()
                    } label: {
                        Label("Feather TFT", systemImage: "plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
