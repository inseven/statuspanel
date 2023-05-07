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

class DeviceModel: ObservableObject, Identifiable, Equatable {

    static func == (lhs: DeviceModel, rhs: DeviceModel) -> Bool {
        return lhs.id == rhs.id
    }

    @ObservedObject var config: Config

    private let dataSourceController: DataSourceController
    let device: Device

    @Published var deviceSettings: DeviceSettings
    @Published var images: [UIImage] = []
    @Published var error: Error? = nil

    @Published var settingsDidChange: UUID = UUID()

    // Creates data source instances on-the-fly to ensure the array always matches the device settings.
    // Instances are cached to ensure this performs and cache cleanup is performed by a subscription.
    @MainActor var dataSources: [DataSourceInstance] {
        get {
            do {
                return try deviceSettings.dataSources.map { dataSourceDetails in
                    if let dataSourceInstance = dataSourceCache[dataSourceDetails.id] {
                        return dataSourceInstance
                    }
                    let dataSourceInstance = try dataSourceController.dataSourceInstance(for: dataSourceDetails)
                    let cancellable = dataSourceInstance.model?.subscribe { [weak self] in
                        guard let self else { return }
                        self.settingsDidChange = UUID()
                    }
                    if let cancellable {
                        dataSourceSubscriptions.append(cancellable)
                    }
                    dataSourceCache[dataSourceDetails.id] = dataSourceInstance
                    return dataSourceInstance
                }
            } catch {
                self.error = error
                return []
            }
        }
    }

    @MainActor private var dataSourceCache: [UUID: DataSourceInstance] = [:]

    private let updateQueue = DispatchQueue(label: "updateQueue")
    private var cancellables: [AnyCancellable] = []
    private var dataSourceSubscriptions: [AnyCancellable] = []

    var id: String { device.id }

    var name: String {
        guard !deviceSettings.name.isEmpty
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

        do {
            self.deviceSettings = try config.settings(forDevice: device.id)
        } catch {
            deviceSettings = DeviceSettings(deviceId: device.id)
            self.error = error
        }
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))

        // Write the settings to disk.
        $deviceSettings
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] deviceSettings in
                guard let self else { return }
                do {
                    try self.config.save(settings: deviceSettings, deviceId: self.device.id)
                } catch {
                    self.error = error
                }
            }
            .store(in: &cancellables)

        // Generate previews whenever the device settings or individual data source settings change, or the app
        // enters the foreground.
        $deviceSettings
            .combineLatest($settingsDidChange, NotificationCenter.default.willEnterForegroundPublisher())
            .debounce(for: 1, scheduler: updateQueue)
            .compactMap { $0.0 }
            .compactMap { [weak self] deviceSettings -> (DeviceSettings, [DataItemBase])? in
                guard let self else { return nil }
                dispatchPrecondition(condition: .onQueue(self.updateQueue))
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

        // Purge the data source instance cache when data sources chanege and subscribe to the data source models
        // to ensure we can respond to changes in data source instance settings.
        $deviceSettings
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] deviceSettings in
                guard let self else { return }
                let dataSourceDetails = deviceSettings.dataSources
                let identifiers = Set(dataSourceDetails.map { $0.id })
                let deletions = self.dataSourceCache.keys.filter { !identifiers.contains($0) }
                deletions.forEach { self.dataSourceCache.removeValue(forKey: $0) }
            }
            .store(in: &cancellables)

    }

}
