// Copyright (c) 2018-2022 Jason Morley, Tom Sutcliffe
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

import Foundation

func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

func LocalizedOffset(_ offset: Int) -> String {
    switch offset {
    case 0:
        return "Today"
    case 1:
        return "Tomorrow"
    default:
        return "Unknown"
    }
}

func Localize(_ darkModeConfig: Config.DarkModeConfig) -> String {
    switch darkModeConfig {
    case .off:
        return LocalizedString("dark_mode_config_off")
    case .on:
        return LocalizedString("dark_mode_config_on")
    case .system:
        return LocalizedString("dark_mode_config_system")
    }
}

func Localize(_ style: FlagsSection.Style) -> String {
    switch style {
    case .title:
        return LocalizedString("flags_section_style_value_title")
    case .body:
        return LocalizedString("flags_section_style_value_body")
    }
}
