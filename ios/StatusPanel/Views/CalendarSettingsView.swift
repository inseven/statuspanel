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

import EventKit
import SwiftUI

struct CalendarSettingsView: View {

    private struct Source: Identifiable {

        var id: String { source.sourceIdentifier }

        let source: EKSource
        let calendars: [EKCalendar]

    }

    var store: DataSourceSettingsStore<CalendarDataSource.Settings>
    @State var settings: CalendarDataSource.Settings

    private var eventStore: EKEventStore

    @State var error: Error? = nil

    @State private var sources: [Source] = []

    init(store: DataSourceSettingsStore<CalendarDataSource.Settings>,
         settings: CalendarDataSource.Settings,
         eventStore: EKEventStore) {
        self.store = store
        self.settings = settings
        self.eventStore = eventStore
    }

    private func loadSources() -> [Source] {
        var sources: [Source] = []
        let allSources = eventStore.sources.sorted(by: { $0.title.compare($1.title) == .orderedAscending})
        for source in allSources {
            let sourceCalendars = source.calendars(for: .event)
            if sourceCalendars.count > 0 {
                let sortedCalendars = sourceCalendars.sorted { $0.title.compare($1.title) == .orderedAscending }
                let summary = Source(source: source, calendars: sortedCalendars)
                sources.append(summary)
            }
        }
        return sources
    }

    var body: some View {
        Form {
            Section {
                Picker(LocalizedString("calendar_day_label"), selection: $settings.offset) {
                    Text(LocalizedOffset(0)).tag(0)
                    Text(LocalizedOffset(1)).tag(1)
                }
                Toggle(LocalizedString("calendar_show_locations_label"), isOn: $settings.showLocations)
                if settings.showLocations {
                    Toggle(LocalizedString("calendar_show_urls_label"), isOn: $settings.showUrls)
                }
            }
            ForEach(sources) { source in
                Section(header: Text(source.source.title)) {
                    ForEach(source.calendars) { calendar in
                        Toggle(calendar.title, isOn: $settings.activeCalendars.binding(for: calendar.calendarIdentifier))
                            .toggleStyle(ColoredCheckbox(color: calendar.color))
                    }
                }
            }
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
        .onAppear {
            sources = loadSources()
        }
    }

}