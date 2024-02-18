// Copyright (c) 2018-2024 Jason Morley, Tom Sutcliffe
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
    private var updateCancellable: AnyCancellable? = nil

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
                self.deviceModels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                newDeviceModels.forEach { $0.start() }
            }
            .store(in: &cancellables)

        // Subscribe to all the device models to ensure we generate updates whenever they change.
        // This is a pretty gnarly implementation to ensure we're not trigger happy. Specifically, it doesn't watch the
        // top-level device model `objectWillChange` publisher as this also includes the preview images; instead, it
        // watches just the `deviceSettings` and `settingsDidChange` publishers as these model config changes.
        $deviceModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceModels in
                guard let self else { return }
                let deviceModelChangePublishers = self.deviceModels.map { deviceModel in
                    return deviceModel
                        .$deviceSettings
                        .combineLatest(deviceModel.$settingsDidChange)
                }
                self.updateCancellable = Publishers.MergeMany(deviceModelChangePublishers)
                    .combineLatest(NotificationCenter.default.willEnterForegroundPublisher())
                    .debounce(for: 1, scheduler: DispatchQueue.main)
                    .sink { [weak self] _ in
                        guard let self else { return }
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.updateDevices()
                        withAnimation {
                            let sortedDeviceModels = self.deviceModels.sorted {
                                $0.name.localizedStandardCompare($1.name) == .orderedAscending
                            }
                            if self.deviceModels != sortedDeviceModels {
                                self.deviceModels = sortedDeviceModels
                            }
                        }
                    }
            }
            .store(in: &cancellables)

        $deviceModels
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] deviceModels in
                guard let self else { return }
                if deviceModels.isEmpty {
                    self.sheet = .add
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
