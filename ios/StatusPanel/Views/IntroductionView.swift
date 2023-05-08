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

struct IntroductionView: View {

    @Environment(\.dismiss) var dismiss

    @ObservedObject var config: Config
    @ObservedObject var applicationModel: ApplicationModel

    let onScanQRCode: () -> Void
    let onAddDemoDevice: () -> Void

    @State var scanQRCode: Bool = false

    init(config: Config,
         applicationModel: ApplicationModel,
         completion: @escaping () -> Void,
         onAddDemoDevice: @escaping () -> Void) {
        self.config = config
        self.applicationModel = applicationModel
        self.onScanQRCode = completion
        self.onAddDemoDevice = onAddDemoDevice
    }

    var body: some View {
        ScrollView {
            VStack {
                Image("Hero")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Viverra maecenas accumsan lacus vel facilisis volutpat est velit egestas. Sit amet facilisis magna etiam tempor. Rutrum quisque non tellus orci ac auctor augue.")
                    .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button {
                    onScanQRCode()
                } label: {
                    Text("Scan QR Code")
                        .centerContent()
                }
                .buttonStyle(.borderedProminent)
                Button {
                    onAddDemoDevice()
                } label: {
                    Text("Add Demo Device")
                        .centerContent()
                }
                .buttonStyle(.bordered)
                if config.showDeveloperTools {
                    Button {
                        dismiss()
                        applicationModel.addFromClipboard()
                    } label: {
                        Text("Add From Clipboard")
                            .centerContent()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
            .padding()
            .background(.background)
        }
        .navigationDestination(isPresented: $scanQRCode) {
            Text("Scan QR Code")
        }

        .navigationTitle("StatusPanel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            
            // Don't allow the view to be dismissed if there are no devices.
            if !applicationModel.deviceModels.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }

        }
        .interactiveDismissDisabled(applicationModel.deviceModels.isEmpty)
    }

}
