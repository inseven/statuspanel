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

    @State var isHidden = false

    var body: some View {
        VStack {
            ZStack {
                if let image = applicationModel.code {
                    Image(nsImage: image)
                }
                if let image = applicationModel.lastUpdate?.images[applicationModel.index] {
                    Image(nsImage: image)
                }
            }
            .frame(width: CGFloat(Device.v1.width), height: CGFloat(Device.v1.height))
            .background(.white)
            .padding()
            if let pairingURL = applicationModel.identifier?.pairingURL.absoluteString {
                LabeledContent("Pairing URL", value: pairingURL)
            }
            if let identifier = applicationModel.identifier {
                LabeledContent("Identifier", value: identifier.id.uuidString)
            }
            if let update = applicationModel.lastUpdate {
                LabeledContent("Wakeup Time", value: String(update.wakeupTime))
            }
        }
        .textSelection(.enabled)
        .toolbar(id: "main") {
            ToolbarItem(id: "action") {
                Button {
                    applicationModel.action()
                } label: {
                    Label("Action", systemImage: "button.programmable")
                }
            }
            ToolbarItem(id: "refresh") {
                Button {
                    applicationModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(id: "reset") {
                Button {
                    applicationModel.reset()
                } label: {
                    Label("Reset", systemImage: "trash")
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
