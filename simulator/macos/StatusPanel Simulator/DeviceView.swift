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

struct DeviceView: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @ObservedObject var deviceModel: DeviceModel
    @State var isShowingInfo = false

    var body: some View {
        VStack(alignment: .trailing) {
            ZStack {
                if let image = deviceModel.code {
                    Image(nsImage: image)
                }
                if let image = deviceModel.lastUpdate?.images[deviceModel.index] {
                    Image(nsImage: image)
                }
            }
            .frame(width: CGFloat(deviceModel.configuration.size.width),
                   height: CGFloat(deviceModel.configuration.size.height))
            .background(.white)
            HStack {
                Text(deviceModel.name)
                    .foregroundColor(.secondary)
                Button {
                    deviceModel.action()
                } label: {
                    Image(systemName: "button.programmable")
                        .help("Action")
                }
                Button {
                    deviceModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .help("Refresh")
                }
                Button {
                    applicationModel.remove(device: deviceModel)
                } label: {
                    Image(systemName: "trash")
                        .help("Delete")
                }
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .help("Show device information")
                }
                .popover(isPresented: $isShowingInfo) {
                    Form {
                        if let pairingURL = deviceModel.configuration.pairingURL.absoluteString {
                            LabeledContent("Pairing URL", value: pairingURL)
                        }
                        if let identifier = deviceModel.configuration {
                            LabeledContent("Identifier", value: identifier.id.uuidString)
                        }
                        if let update = deviceModel.lastUpdate {
                            LabeledContent("Wakeup Time", value: String(update.wakeupTime))
                        }
                    }
                    .formStyle(.grouped)
                    .frame(maxWidth: 400)
                }
            }
            .buttonStyle(.borderless)
        }
    }

}
