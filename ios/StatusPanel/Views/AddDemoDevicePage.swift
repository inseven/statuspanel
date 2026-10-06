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

import Combine
import SwiftUI

struct AddDemoDevicePage: View {

    let complete: @MainActor (ExternalOperation) -> Void

    init(complete: @escaping @MainActor (ExternalOperation) -> Void) {
        self.complete = complete
    }

    var body: some View {
        ScrollView {
            VStack {
                ForEach(Device.Kind.demoDevices) { kind in
                    Button {
                        complete(ExternalOperation.registerDevice(Device(kind: kind)))
                    } label: {
                        Text(Localized(kind))
                            .centerContent()
                    }
                }
                Button {
                    let device = Device(kind: .einkV1)
                    let operation = ExternalOperation.registerDeviceAndConfigureWiFi(device, ssid: "demo")
                    complete(operation)
                } label: {
                    Text("WiFi Device")
                        .centerContent()
                }
            }
            .padding()
        }
        .navigationTitle("Add Demo Device")
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

}
