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

struct CalendarPicker: View {

    private struct Source: Identifiable {

        var id: String { source.sourceIdentifier }

        let source: EKSource
        let calendars: [EKCalendar]

    }

    private var eventStore: EKEventStore
    @Binding private var selection: Set<String>
    @State private var shadowSelection: Set<String>

    @State private var sources: [Source] = []

    init(eventStore: EKEventStore, selection: Binding<Set<String>>) {
        self.eventStore = eventStore
        _selection = selection
        _shadowSelection = State(initialValue: selection.wrappedValue)
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
            ForEach(sources) { source in
                Section(header: Text(source.source.title)) {
                    ForEach(source.calendars) { calendar in
                        Toggle(calendar.title, isOn: $shadowSelection.binding(for: calendar.calendarIdentifier))
                            .toggleStyle(ColoredCheckbox(color: calendar.color))
                    }
                }
            }
        }
        .onChange(of: shadowSelection) { selection in
            self.selection = selection
        }
        .onAppear {
            sources = loadSources()
        }
    }

}
