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

struct Device {

    let width: Int
    let height: Int

    static let v1 = Device(width: 640, height: 384)

}

struct ContentView: View {

    @EnvironmentObject var applicationModel: ApplicationModel

    @State var isHidden = false

    var body: some View {
        ZStack {
            if let image = applicationModel.code {
                Image(nsImage: image)
            }
            if let defaultImage = applicationModel.contents,
               let privacyImage = applicationModel.security {
                if !isHidden {
                    Image(nsImage: defaultImage)
                } else {
                    Image(nsImage: privacyImage)
                }
            }
        }
        .frame(width: CGFloat(Device.v1.width), height: CGFloat(Device.v1.height))
        .background(.white)
        .padding()
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $isHidden) {
                    Label("Refresh", systemImage: "eye.slash.fill")
                }
            }
            ToolbarItem {
                Button {
                    // TODO: This task should be hidden in the model
                    Task {
                        try? await applicationModel.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
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
