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

class DeviceModel: ObservableObject, Identifiable {

    var id: UUID { configuration.id }

    var configuration: DeviceConfiguration
    @Published var code: NSImage? = nil
    @Published var lastUpdate: Service.Update? = nil
    @Published var index: Int = 0

    var name: String {
        switch configuration.kind {
        case .einkV1:
            return "eInk Version 1"
        case .featherTft:
            return "Feather TFT"
        case .pimoroniInkyImpression4:
            return "Pimoroni Inky Impression 4"
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    init(identifier: DeviceConfiguration) {
        self.configuration = identifier
    }

    func start() {

        self.code = NSImage.generateQRCode(from: configuration.pairingURL.absoluteString)!

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .prepend(NSNotification(name: NSApplication.didBecomeActiveNotification, object: NSApplication.shared) as NotificationCenter.Publisher.Output)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refresh()
            }
            .store(in: &cancellables)
    }

    @MainActor func action() {
        guard let lastUpdate else { return }
        index = (index + 1) % lastUpdate.images.count
    }

    func refresh() {
        Task {
            do {
                let update = try await Service.update(configuration: self.configuration)
                await MainActor.run {
                    self.lastUpdate = update
                }
            } catch {
                // TODO: Handle the error
                print("Failed to update with error \(error)")
            }
        }
    }


}
