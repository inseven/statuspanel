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

    @ObservedObject var config: Config

    private let dataSourceController: DataSourceController
    private let device: Device

    @Published var deviceSettings: DeviceSettings? = nil
    @Published var images: [UIImage] = []

    private var cancellables: [AnyCancellable] = []

    var id: String { device.id }

    var name: String {
        guard let deviceSettings,
              !deviceSettings.name.isEmpty
        else {
            return Localized(device.kind)
        }
        return deviceSettings.name
    }

    init(config: Config, dataSourceController: DataSourceController, device: Device) {
        self.config = config
        self.dataSourceController = dataSourceController
        self.device = device
        self.images = [device.blankImage()]
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))

        // Fetch settings.
        config
            .objectWillChange
            .prepend(())
            .combineLatest(NotificationCenter.default
                .publisher(for: UIApplication.willEnterForegroundNotification)
                .prepend(NSNotification(name: UIApplication.willEnterForegroundNotification, object: nil) as NotificationCenter.Publisher.Output))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                do {
                    self.deviceSettings = try self.config.settings(forDevice: self.device.id)
                } catch {
                    print("Failed to preview device with error \(error).")
                }
            }
            .store(in: &cancellables)

        // Generate previews.
        $deviceSettings
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .compactMap { $0 }
            .compactMap { [weak self] deviceSettings -> (DeviceSettings, [DataItemBase])? in
                guard let self else { return nil }
                let semaphore = DispatchSemaphore(value: 0)
                var result: [DataItemBase]?
                self.dataSourceController.fetch(details: deviceSettings.dataSources) { items, error in
                    result = items
                    semaphore.signal()
                }
                semaphore.wait()
                guard let items = result else {
                    return nil
                }
                return (deviceSettings, items)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (settings, items) in
                guard let self else { return }
                let images = self.device.renderer.render(data: items,
                                                         config: self.config,
                                                         device: self.device,
                                                         settings: settings)
                self.images = images
            }
            .store(in: &cancellables)
    }

}
