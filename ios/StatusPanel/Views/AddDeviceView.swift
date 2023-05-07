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

struct AddDeviceView: View {

    class Model: ObservableObject {

        @Published var showInvalidCodeError = false

        private var cancellables: Set<AnyCancellable> = []

        @MainActor func start() {
            $showInvalidCodeError
                .delay(for: 3.0, scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    guard self.showInvalidCodeError else { return }
                    withAnimation {
                        self.showInvalidCodeError = false
                    }
                }
                .store(in: &cancellables)
        }

        @MainActor func showError() {
            withAnimation {
                showInvalidCodeError = true
            }
        }

    }

    enum Page: Hashable {
        case scan
        case configureWiFi(Device, String)
        case demoDevice
    }

    @Environment(\.dismiss) var dismiss

    var applicationModel: ApplicationModel

    @StateObject var model = Model()
    @State var pages: [Page] = []

    var body: some View {
        NavigationStack(path: $pages) {
            IntroductionView(applicationModel: applicationModel) {
                pages.append(.scan)
            } onAddDemoDevice: {
                pages.append(.demoDevice)
            }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .scan:
                    QRCodeView { url in
                        guard let operation = ExternalOperation(url: url) else {
                            model.showError()
                            return false
                        }
                        switch operation {
                        case .registerDevice(let device):
                            applicationModel.addDevice(device)
                            dismiss()
                        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
                            pages.append(.configureWiFi(device, ssid))
                        }
                        return true
                    }
                    .edgesIgnoringSafeArea(.all)
                    .navigationTitle("Scan QR Code")
                    .toolbarBackground(.visible, for: .navigationBar)
                case .configureWiFi(let device, let ssid):
                    WiFiProvisionerView(device: device, ssid: ssid) { device in
                        applicationModel.addDevice(device)
                        dismiss()
                    } cancel: {
                        dismiss()
                    }
                    .edgesIgnoringSafeArea(.all)
                case .demoDevice:
                    ScrollView {
                        ForEach(Device.Kind.allCases) { kind in
                            Button {
                                applicationModel.addDemoDevice(kind: kind)
                            } label: {
                                Text(Localized(kind))
                                    .centerContent()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding()
                    }
                    .navigationTitle("Add Demo Device")
                }
            }
        }
        .overlay {
            if model.showInvalidCodeError {
                VStack {
                    Spacer()
                    Text("Invalid QR Code")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(8.0)
                        .padding()
                }
            }
        }
        .onAppear {
            model.start()
        }
    }

}
