// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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

struct FlagsSection: View {

    @Binding var flags: DataItemFlags

    enum Style {
        case title
        case body
    }

    func style() -> Binding<Style> {
        Binding {
            if flags.contains(.header) {
                return .title
            }
            return .body
        } set: { newValue in
            switch newValue {
            case .title:
                flags.insert(.header)
            case .body:
                flags.remove(.header)
            }
        }
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
            Picker("Style", selection: style()) {
                Text("Title").tag(Style.title)
                Text("Body").tag(Style.body)
            }
            Toggle("Prefers Empty Column", isOn: prefersEmptyColumn())
            Toggle("Spans Columns", isOn: spansColumns())
        }
    }

}
