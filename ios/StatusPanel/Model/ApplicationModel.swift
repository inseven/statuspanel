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
import UIKit

class ApplicationModel: ObservableObject {

    enum SheetType: Identifiable {
        var id: Self { return self }

        case settings
        case add
    }

    private let dataSourceController: DataSourceController
    private let config: Config

    private var cancellables: Set<AnyCancellable> = []

    @Published var deviceModels: [DeviceModel] = []
    @Published var sheet: SheetType? = nil

    init(dataSourceController: DataSourceController, config: Config) {
        self.dataSourceController = dataSourceController
        self.config = config
    }

    func start() {

        // Keep the list of devices up to date.
        config
            .$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                var identifiers = Set(devices.map { $0.id })
                self.deviceModels.removeAll { !identifiers.contains($0.id) }
                self.deviceModels.forEach { identifiers.remove($0.id) }
                let newDevices = devices.filter { identifiers.contains($0.id) }
                let newDeviceModels = newDevices.map { device in
                    return DeviceModel(config: self.config,
                                       dataSourceController: self.dataSourceController,
                                       device: device)
                }
                self.deviceModels.append(contentsOf: newDeviceModels)
                newDeviceModels.forEach { $0.start() }
            }
            .store(in: &cancellables)

        // Generate per-device updates for upload.
        // Ultimately we may wish to push this update generate down to the device models to avoid duplicate effort and
        // guarantee that what's displayed in the UI matches what's shown on-device.
        config
            .objectWillChange
            .prepend(())
            .combineLatest(NotificationCenter.default
                .publisher(for: UIApplication.willEnterForegroundNotification)
                .prepend(NSNotification(name: UIApplication.willEnterForegroundNotification, object: nil) as NotificationCenter.Publisher.Output))
            .receive(on: DispatchQueue.main)
            .sink { _ in
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.updateDevices()
            }
            .store(in: &cancellables)

        $deviceModels
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] deviceModels in
                guard let self else { return }
                if deviceModels.isEmpty {
                    sheet = .add
                }
            }
            .store(in: &cancellables)
    }

    @MainActor func addFromClipboard() {
        guard let clipboard = UIPasteboard.general.string,
           let url = URL(string: clipboard) else {
            return
        }
        _ = AppDelegate.shared.application(UIApplication.shared, open: url, options: [:])
    }

    @MainActor func addDemoDevice(kind: Device.Kind) {
        AppDelegate.shared.addDevice(Device(kind: kind))
    }

    @MainActor func showIntroduction() {
        sheet = .add
    }

    @MainActor func addDevice(_ device: Device) {
        AppDelegate.shared.addDevice(device)
    }

}
