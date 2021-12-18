// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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
import UIKit

protocol IntroductionViewModel {

    func addDummyDevice()
    func next()

}

struct IntroductionView: View {

    var model: IntroductionViewModel

    var body: some View {
        VStack {
            Image("AddDeviceHeader")
                .resizable()
                .aspectRatio(contentMode: .fit)
            VStack {
                Text("Add a StatusPanel")
                    .font(.headline)
                    .padding(.bottom)
                Text("Scan the QR code on your new StatusPanel to connect your calendar and set up other content sources.\n\nIf you don't have a StatusPanel and would like to try the app out, try the Demo Mode.")
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
            Button {
                model.addDummyDevice()
            } label: {
                Text("Demo Mode")
                    .frame(minWidth: 300)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button {
                model.next()
            } label: {
                Text("Continue")
                    .frame(minWidth: 300)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .edgesIgnoringSafeArea(.top)
    }

}
