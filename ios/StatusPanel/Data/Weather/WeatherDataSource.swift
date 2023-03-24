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

import CoreLocation
import SwiftUI
import WeatherKit

import Diligence

final class WeatherDataSource: DataSource {

    struct Settings: DataSourceSettings & Equatable {
        var flags: DataItemFlags
        var address: String
    }

    struct SettingsView: View {

        var store: Store
        @State var settings: Settings
        @State var error: Error? = nil

        var body: some View {
            Form {
                Section {
                    TextField("Address", text: $settings.address)
                }
                FlagsSection(flags: $settings.flags)
            }
            .alert(isPresented: $error.mappedToBool()) {
                Alert(error: error)
            }
            .onChange(of: settings) { newValue in
                do {
                    try store.save(settings: newValue)
                } catch {
                    self.error = error
                }
            }

        }

    }

    let id: DataSourceType = .weather
    let name = "Weather"
    let image = UIImage(systemName: "cloud.sun", withConfiguration: UIImage.SymbolConfiguration(scale: .large))!
    let configurable = true
    let defaults = Settings(flags: [], address: "Bletchley Park, Sherwood Drive, Bletchley, Milton Keynes, MK3 6EB")

    func data(settings: Settings, completion: @escaping ([DataItemBase], Error?) -> Void) {
        guard #available(iOS 16.0, *) else {
            completion([DataItem(text: "Unsupported", flags: settings.flags)], nil)
            return
        }
        Task.detached {
            do {
                let geocoder = CLGeocoder()
                let locations = try await geocoder.geocodeAddressString(settings.address)
                print("locations = \(locations)")
                guard let location = locations.first?.location else {
                    completion([DataItem(text: "Unknown Location", flags: settings.flags)], nil)
                    return
                }
                let weather = try await WeatherService.shared.weather(for: location)
                guard let today = weather.dailyForecast.forecast.first else {
                    return
                }

                let emoji: String?
                switch today.condition {
                case .blizzard:
                    emoji = "🌨️"
                case .blowingDust:
                    emoji = "💨"
                case .blowingSnow:
                    emoji = "🌨️"
                case .breezy:
                    emoji = "💨"
                case .clear:
                    emoji = "☀️"
                case .cloudy:
                    emoji = "☁️"
                case .drizzle:
                    emoji = "🌧️"
                case .flurries:
                    emoji = "🌨️"
                case .foggy:
                    emoji = "😶‍🌫️"
                case .freezingDrizzle:
                    emoji = "🌧️"
                case .freezingRain:
                    emoji = "🌧️"
                case .frigid:
                    emoji = "🥶"
                case .hail:
                    emoji = "🌨️"
                case .haze:
                    emoji = "😶‍🌫️"
                case .heavyRain:
                    emoji = "💧"
                case .heavySnow:
                    emoji = "❄️"
                case .hot:
                    emoji = "🥵"
                case .hurricane:
                    emoji = "🌪️"
                case .isolatedThunderstorms:
                    emoji = "🌩️"
                case .mostlyClear:
                    emoji = "🌤️"
                case .mostlyCloudy:
                    emoji = "🌥️"
                case .partlyCloudy:
                    emoji = "⛅️"
                case .rain:
                    emoji = "🌧️"
                case .scatteredThunderstorms:
                    emoji = "🌩️"
                case .sleet:
                    emoji = "🌨️"
                case .smoky:
                    emoji = "🔥"
                case .snow:
                    emoji = "🌨️"
                case .strongStorms:
                    emoji = "⛈️"
                case .sunFlurries:
                    emoji = "🌦️"
                case .sunShowers:
                    emoji = "🌦️"
                case .thunderstorms:
                    emoji = "🌩️"
                case .tropicalStorm:
                    emoji = "🌪️"
                case .windy:
                    emoji = "💨"
                case .wintryMix:
                    emoji = "🌨️"
                @unknown default:
                    emoji = nil
                }

                let temperatureSummary = String(format: "H:%d° L:%d°",
                                                Int(today.highTemperature.value),
                                                Int(today.lowTemperature.value))
                let dataItem = DataItem(icon: emoji, text: temperatureSummary, flags: settings.flags)
                completion([dataItem], nil)
            } catch {
                print("failed to fetch weather with error \(error)")
                completion([], error)
            }
        }
    }

    func summary(settings: Settings) -> String? {
        return settings.address
    }

    func settingsViewController(store: Store, settings: Settings) -> UIViewController? {
        return UIHostingController(rootView: SettingsView(store: store, settings: settings))
    }

}
