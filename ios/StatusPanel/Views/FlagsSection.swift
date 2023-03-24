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

import SwiftUI

extension DataItemFlags {

    var style: FlagsSection.Style {
        get {
            if contains(.header) {
                return .title
            }
            return .body
        }
        set {
            switch newValue {
            case .title:
                insert(.header)
            case .body:
                remove(.header)
            }
        }
    }

}

struct FlagsSection: View {

    @Binding var flags: DataItemFlags
    @State var isShowingStyle = false

    enum Style {
        case title
        case body
    }

    func prefersEmptyColumn() -> Binding<Bool> {
        Binding {
            flags.contains(.prefersEmptyColumn)
        } set: { newValue in
            if newValue == true {
                flags.insert(.prefersEmptyColumn)
            } else {
                flags.remove(.prefersEmptyColumn)
            }
        }
    }

    func spansColumns() -> Binding<Bool> {
        Binding {
            flags.contains(.spansColumns)
        } set: { newValue in
            if newValue == true {
                flags.insert(.spansColumns)
            } else {
                flags.remove(.spansColumns)
            }
        }
    }

    var body: some View {
        Section(header: Text("Display")) {
            NavigationLink(destination: List {
                Button {
                    flags.style = .title
                    isShowingStyle = false
                } label: {
                    HStack {
                        Text(Localize(Style.title))
                        Spacer()
                        if flags.style == .title {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .foregroundColor(.primary)
                }
                Button {
                    flags.style = .body
                    isShowingStyle = false
                } label: {
                    HStack {
                        Text(Localize(Style.body))
                        Spacer()
                        if flags.style == .body {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Style"), isActive: $isShowingStyle) {
                HStack {
                    Text(LocalizedString("flags_section_style_label"))
                    Spacer()
                    Text(Localize(flags.style))
                        .foregroundColor(.secondary)
                }
            }

            Toggle(LocalizedString("flags_section_prefers_empty_column_label"), isOn: prefersEmptyColumn())
            Toggle(LocalizedString("flags_section_spans_columns_label"), isOn: spansColumns())
        }
    }

}
