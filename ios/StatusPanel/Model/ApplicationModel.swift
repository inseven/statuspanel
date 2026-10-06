// Copyright (c) 2018-2026 Jason Morley, Tom Sutcliffe
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
import EventKit
import SwiftUI
import UIKit

class ApplicationModel: ObservableObject {

    enum SheetType: Identifiable {
        var id: String {
            switch self {
            case .settings:
                return "settings"
            case .add(let page):
                return "add-\(page.id)"
            }
        }

        case settings
        case add(AddDeviceView.Page)
    }

    public let dataSourceController: DataSourceController
    private let config: Config

    private let client: Service = Service(baseUrl: "https://api.statuspanel.io/")

    @MainActor private var cancellables: Set<AnyCancellable> = []
    @MainActor private var updateCancellable: AnyCancellable? = nil

    @MainActor @Published var deviceModels: [DeviceModel] = []
    @MainActor @Published var selection: String? = nil
    @MainActor @Published var sheet: SheetType? = nil
    @MainActor @Published var error: Error? = nil

    init(dataSourceController: DataSourceController, config: Config) {
        self.dataSourceController = dataSourceController
        self.config = config
    }

    @MainActor func start() {

        // Keep the list of devices up to date.
        config
            .$devices
            .sinkOnMain { [weak self] devices in
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
            .sinkOnMain { [weak self] deviceModels in
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
                        updateDevices()
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
            .debounceOnMain(for: 0.5) { [weak self] deviceModels in
                guard let self else { return }
                if deviceModels.isEmpty {
                    showIntroduction()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor func addFromClipboard() {
//        guard let clipboard = UIPasteboard.general.string,
//           let url = URL(string: clipboard) else {
//            return
//        }
//        _ = AppDelegate.shared.application(UIApplication.shared, open: url, options: [:])
    }

    func configureDataSourceInstance<T: DataSourceSettings>(type: DataSourceType,
                                                            settings: T) throws -> DataSourceInstance.Details {
        let instanceId = UUID()
        let details = DataSourceInstance.Details(id: instanceId, type: type)
        try Config.shared.save(settings: settings, instanceId: instanceId)
        return details
    }

    func configureDataSourceInstances(_ dataSourceSettings: [AnyDataSourceSettings]) throws -> [DataSourceInstance.Details] {
        var result: [DataSourceInstance.Details] = []
        for settings in dataSourceSettings {
            let instanceId = UUID()
            let details = DataSourceInstance.Details(id: instanceId, type: settings.dataSourceType)
            try Config.shared.save(settings: settings, instanceId: instanceId)
            result.append(details)
        }
        return result
    }

    @MainActor func addDemoDevice(kind: Device.Kind) {
        addDevice(Device(kind: kind))
    }

    @MainActor func showIntroduction() {
        sheet = .add(.introduction)
    }

    // Set up the initial data sources if necessary.
    // This is a little inelegant as it presumes we'll only need to request access to EKEventStore and hard-codes
    // that request here--a better approach would be to introduce a an asynchronous DataSource API that allows
    // each source to request access to the stores it requires.
    @MainActor func addDevice(_ device: Device) {
        let eventStore = EKEventStore()
        eventStore.requestAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let config = Config.shared
                do {
                    let calendars = eventStore.allCalendars().map { $0.calendarIdentifier }
                    var settings = device.defaultSettings()
                    let dataSourceSettings = device.defaultDataSourceSettings(calendars: calendars)
                    settings.dataSources = try self.configureDataSourceInstances(dataSourceSettings)
                    try config.save(settings: settings, deviceId: device.id)
                } catch {
                    self.error = error
                    return
                }
                config.devices.insert(device)
                DispatchQueue.main.async {
                    withAnimation {
                        self.sheet = nil
                        self.selection = device.id
                    }
                }
            }
        }
    }

    @MainActor
    func openURL(_ url: URL) {
        guard let operation = ExternalOperation(url: url) else {
            error = StatusPanelError.invalidUrl
            return
        }

        switch operation {
        case .registerDevice(let device):
            addDevice(device)
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            self.sheet = .add(.configureWiFi(device, ssid))
        }
    }

    func registerDevice(token: Data) {
        print("Registering device...")
        self.client.registerDevice(token: token) { success, error in
            guard success else {
                print("Failed to register device with error \(String(describing: error)).")
                return
            }
            print("Successfully registered device.")
        }
    }

    // Fetch items, generate updates, and upload per-device updates.
    // Counter-intuitively, this is now called from the `ApplicationModel` instance as application lifecycle is now
    // split between the model and delegate.
    // Ultimately, this functionality should probably be pushed into `ApplicationModel`.
    func updateDevices(completion: @escaping (UIBackgroundFetchResult) -> Void = { _ in }) {
        Task {
            do {
                let config = Config.shared
                let updates = try await config.devices
                    .asyncMap { device in
                        print("Generating update for \(device.id)...")
                        let settings = try config.settings(forDevice: device.id)
                        let items = try await dataSourceController.fetch(details: settings.dataSources)
                        let images = await MainActor.run {
                            device.renderer.render(data: items, config: config, device: device, settings: settings)
                        }
                        let payloads = Panel.encode(images: images, encoding: device.encoding)
                        return Service.Update(device: device, settings: settings, images: payloads)
                    }
                let change = await client.upload(updates)
                completion(change ? .newData : .noData)
            } catch {
                completion(.failed)
            }
        }
    }

}
