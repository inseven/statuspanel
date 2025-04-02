// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

import UIKit

class PrivacyImageManager {

    static func privacyImageURL(_ filename: String) throws -> URL {
        return try FileManager.default.documentsUrl().appendingPathComponent(filename)
    }

    static func privacyImage(filename: String) throws -> UIImage? {
        let url = try privacyImageURL(filename)
        return UIImage(contentsOfFile: url.path)
    }

    static func writePrivacyImage(_ data: Data) throws -> String {
        guard
            let rawImage = UIImage(data: data),
            let image = rawImage.normalizeOrientation()
        else {
            throw StatusPanelError.invalidImage
        }
        let filename = "privacy-image-\(UUID().uuidString).png"
        let url = try privacyImageURL(filename)
        guard let data = image.pngData() else {
            throw StatusPanelError.invalidImage
        }
        try data.write(to: url, options: [.atomic])
        return filename
    }

    static func removePrivacyImage(_ filename: String) throws {
        let url = try privacyImageURL(filename)
        try FileManager.default.removeItem(at: url)
    }

}
