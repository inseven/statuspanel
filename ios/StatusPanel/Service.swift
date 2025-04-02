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

import Foundation
import UIKit

import Sodium

let IMAGE_FLAG_PNG: UInt16 = 1

class Service {

    struct Update {
        let device: Device
        let settings: DeviceSettings
        let images: [Data]
    }

    let baseUrl: URL

    init(baseUrl: String) {
        var url = URL.init(string: baseUrl)!
        url.appendPathComponent("api/v3")
        self.baseUrl = url
    }

    func registerDevice(token: Data, completionHandler: @escaping (Bool, Error?) -> Void) {

        // Rudimentary mechanism for determining whether to use the APNS sandbox or not.
        // It's actually a lot more complex than this, but debug build (or not) is a pretty good proxy for the behaviour
        // we're after, and doesn't involve parsing mobile provision files, or bringing in additional dependencies.
        #if DEBUG
        let useSandbox = true
        #else
        let useSandbox = false
        #endif

        let json: [String: Any] = [
            "token": token.base64EncodedString(),
            "use_sandbox": useSandbox,
        ]
        do {
            var request = URLRequest(url: self.baseUrl.appendingPathComponent("device/"))
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completionHandler(false, error)
                    return
                }
                let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
                if let responseJSON = responseJSON as? [String: Any] {
                    print(responseJSON)
                }
                completionHandler(true, nil)
            }
            task.resume()
        } catch {
            completionHandler(false, error)
        }
    }

    func upload(updates: [Update], completion: @escaping (Bool) -> Void) {
        Task {
            let didUpload = await upload(updates)
            completion(didUpload)
        }
    }

    func upload(_ updates: [Update]) async -> Bool {
        var result = false
        for update in updates {
            let didUpload = await upload(update.images, device: update.device, settings: update.settings)
            result = result || didUpload
        }
        return result
    }

    // TODO: This should throw errors to make it easier to surface them to the user.
    func upload(_ images: [Data], device: Device, settings: DeviceSettings) async -> Bool {
        let flags = device.encoding == .png ? IMAGE_FLAG_PNG : 0
        let sodium = Sodium()
        guard let key = sodium.utils.base642bin(device.publicKey, variant: .ORIGINAL) else {
            print("Failed to decode key from publickey userdefault!")
            return false
        }

        let localUpdateTime = settings.localUpdateTime()

        // We can't just hash the resulting encryptedData because libsodium ensures it is different every time even
        // for identical input data (which normally is a good thing!) so we have to construct a unencrypted blob just
        // for the purposes of calculating the hash.
        let message = Array(Self.makeMultipartUpload(localUpdateTime: localUpdateTime,
                                                     parts: images,
                                                     flags: flags))
        let hash = sodium.utils.bin2base64(sodium.genericHash.hash(message: message)!, variant: .ORIGINAL)!

        let lastUploadHash = Config.shared.getLastUploadHash(for: device.id)
        guard hash != lastUploadHash else {
            print("Data for \(device.id) is the same as before, not uploading")
            return false
        }

        var encryptedParts: [Data] = []
        for image in images {
            guard let encryptedDataBytes = sodium.box.seal(message: Array(image), recipientPublicKey: key) else {
                print("Failed to seal box")
                return false
            }
            encryptedParts.append(Data(encryptedDataBytes))
        }
        let encryptedData = Self.makeMultipartUpload(localUpdateTime: localUpdateTime,
                                                     parts: encryptedParts,
                                                     flags: flags)
        let url = baseUrl
            .appendingPathComponent("status")
            .appendingPathComponent(device.id)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "---------------------------14737809831466499882746641449"
        let contentType = "multipart/form-data; boundary=\(boundary)"

        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Disposition:form-data; name=\"test\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        body.append("hi\r\n".data(using: String.Encoding.utf8)!)

        let fname = "img_panel_rle"
        let mimetype = "application/octet-stream"

        body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Disposition:form-data; name=\"file\"; filename=\"\(fname)\"\r\n".data(using: String.Encoding.utf8)!)
        body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: String.Encoding.utf8)!)
        body.append(encryptedData)
        body.append("\r\n".data(using: String.Encoding.utf8)!)
        body.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)

        request.httpBody = body

        do {
            _ = try await URLSession.shared.data(for: request)
            Config.shared.setLastUploadHash(for: device.id, to: hash)
        } catch {
            print(error)
            return false
        }

        return true
    }

    private static func makeMultipartUpload(localUpdateTime: TimeInterval, parts: [Data], flags: UInt16) -> Data {
        let wakeTime = Int(localUpdateTime / 60)
        // Header format is as below. Any fields beyond length can be omitted
        // providing the length is set appropriately.
        // FF 00 - indicating header present
        // NN    - Length of header
        // TT TT - wakeup time (oops this is big endian)
        // CC    - count of images (index immediately follows header)
        // GG GG - flags (little endian)
        // II II II II - file offset of image 1 (little endian)
        // index of image 2, etc...
        //
        // Defined flags:
        // 1 IMAGE_FLAG_PNG indicates the images are all in PNG format rather than RLE.
        var data = Data([0xFF, 0x00, 0x08, UInt8(wakeTime >> 8), UInt8(wakeTime & 0xFF), UInt8(parts.count),
                         UInt8(flags & 0xFF), UInt8(flags >> 8)])
        // I'm sure there's a way to do this with UnsafeRawPointers or something, but eh
        let u32le = { (val: Int) -> Data in
            let u32 = UInt32(val)
            return Data([UInt8(u32 & 0xFF), UInt8((u32 & 0xFF00) >> 8), UInt8((u32 & 0xFF0000) >> 16), UInt8(u32 >> 24)])
        }
        var idx = data.count + 4 * parts.count
        for part in parts {
            data += u32le(idx)
            idx += part.count
        }
        for part in parts {
            data += part
        }
        return data
    }

}
