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

import Foundation
import UIKit

import Sodium

class Client {

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

    func upload(image: UIImage, privacyImage: UIImage, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            print("Uploading new images")

            let payloads = Panel.rlePayloads(for: [image, privacyImage])
            let images = payloads.map { $0.0 }

            var devices = Config().devices
            if devices.count == 0 {
                print("No keys configured, not uploading")
                completion(false)
                return
            }

            var nextUpload : (Bool) -> Void = { (b: Bool) -> Void in }
            var anythingUploaded = false
            nextUpload = { (lastUploadDidUpload: Bool) in
                if lastUploadDidUpload {
                    anythingUploaded = true
                }
                if devices.count == 0 {
                    completion(anythingUploaded)
                } else {
                    let (id, pubkey) = devices.remove(at: 0)
                    if pubkey.isEmpty {
                        // Empty keys are used for debugging the UI, and shouldn't cause an upload
                        nextUpload(false)
                        return
                    }
                    self.uploadImages(images, deviceid: id, publickey: pubkey, completion: nextUpload)
                }
            }
            nextUpload(false)
        }
    }

    private func uploadImages(_ images: [Data], deviceid: String, publickey: String, completion: @escaping (Bool) -> Void) {
        let sodium = Sodium()
        guard let key = sodium.utils.base642bin(publickey, variant: .ORIGINAL) else {
            print("Failed to decode key from publickey userdefault!")
            completion(false)
            return
        }

        // We can't just hash the resulting encryptedData because libsodium ensures it is different every time even
        // for identical input data (which normally is a good thing!) so we have to construct a unencrypted blob just
        // for the purposes of calculating the hash.
        let hash = sodium.utils.bin2base64(sodium.genericHash.hash(message: Array(Self.makeMultipartUpload(parts: images)))!, variant: .ORIGINAL)!
        if hash == Config().getLastUploadHash(for: deviceid) {
            print("Data for \(deviceid) is the same as before, not uploading")
            completion(false)
            return
        }

        var encryptedParts: [Data] = []
        for image in images {
            let encryptedDataBytes = sodium.box.seal(message: Array(image), recipientPublicKey: key)
            if encryptedDataBytes == nil {
                print("Failed to seal box")
                completion(false)
                return
            }
            encryptedParts.append(Data(encryptedDataBytes!))
        }
        let encryptedData = Self.makeMultipartUpload(parts: encryptedParts)
        let path = "https://api.statuspanel.io/api/v2/\(deviceid)"
        guard let url = URL(string: path) else {
            print("Unable to create URL")
            completion(false)
            return
        }

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
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            // print(response ?? "")
            if let error = error {
                print(error)
            } else {
                Config().setLastUploadHash(for: deviceid, to: hash)
            }
            completion(true)
        })
        task.resume()
    }

    private static func makeMultipartUpload(parts: [Data]) -> Data {
        let wakeTime = Int(Config.getLocalWakeTime() / 60)
        // Header format is as below. Any fields beyond length can be omitted
        // providing the length is set appropriately.
        // FF 00 - indicating header present
        // NN    - Length of header
        // TT TT - wakeup time
        // CC    - count of images (index immediately follows header)
        var data = Data([0xFF, 0x00, 0x06, UInt8(wakeTime >> 8), UInt8(wakeTime & 0xFF), UInt8(parts.count)])
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
