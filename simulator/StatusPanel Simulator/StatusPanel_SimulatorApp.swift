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

import Combine
import SwiftUI

import DataStream
import Sodium

// TODO: MainActor?
class ApplicationModel: ObservableObject {

    // TODO: Tuple of device ID and keypair?
    let id: String = "aaaaaaaa"
    @Published var keyPair: Box.KeyPair
    @Published var code: NSImage? = nil

    @Published var contents: NSImage? = nil
    @Published var security: NSImage? = nil

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let userDefaults = UserDefaults.standard
        if let publicKey = userDefaults.object(forKey: "publicKey") as? Data,
           let secretKey = userDefaults.object(forKey: "secretKey") as? Data {
            keyPair = Box.KeyPair(publicKey: Array(publicKey), secretKey: Array(secretKey))
        } else {
            let sodium = Sodium()
            keyPair = sodium.box.keyPair()!
            userDefaults.set(Data(keyPair.publicKey), forKey: "publicKey")
            userDefaults.set(Data(keyPair.secretKey), forKey: "secretKey")
        }

        start()
    }

    func start() {

        // TODO: Update the QR code on a different queue
        // TODO: Handle failures more cleanly.
        $keyPair
            .receive(on: DispatchQueue.main)
            .map { keyPair in
                let sodium = Sodium()
                let publicKeyBase64 = sodium.utils.bin2base64(keyPair.publicKey, variant: .ORIGINAL)!

                var components = URLComponents()
                components.scheme = "statuspanel"
                components.path = "r2"
                components.queryItems = [
                    URLQueryItem(name: "id", value: "aaaaaaaa"),
                    URLQueryItem(name: "pk", value: publicKeyBase64),
                ]

                return components.url!
            }
            .map { url in
                return NSImage.generateQRCode(from: url.absoluteString)!
            }
            .sink { [weak self] image in
                guard let self else { return }
                self.code = image
            }
            .store(in: &cancellables)
    }

    func update() async throws {
        let url = URL(string: "https://api.statuspanel.io/api/v2")!
            .appendingPathComponent(id)

        let response = try await URLSession.shared.data(from: url)
        let data = response.0

        let sodium = Sodium()
        let stream = DataReadStream(data: data)

        // Check for a header marker.
        let marker: UInt16 = try stream.read()
        guard marker == 0xFF00 else {
            print("Invalid header")
            return
        }

        // Read the header.
        let headerLength: UInt8 = try stream.read()
        let wakeupTime: UInt16 = try stream.read()
        let imageCount: UInt8?
        if headerLength >= 6 {
            imageCount = try stream.read()
        } else {
            imageCount = nil
        }

        // If an image count has been defined, then an index immediately follows the
        // header giving the index of each image.
        var offsets: [UInt32] = []
        if let imageCount = imageCount {
            for _ in 0..<imageCount {
                offsets.append(try stream.readle())
            }
        } else {
            offsets = [0]
        }

        // Convert the offsets to ranges by walking backwards through them and tracking
        // the previous offset as a length.
        var ranges: [(UInt32, UInt32)] = []
        var end: UInt32 = UInt32(data.count)
        for offset in offsets.reversed() {
            ranges.insert((offset, end), at: 0)
            end = offset
        }

        print(headerLength)
        print(wakeupTime)
        print(imageCount ?? 1)
        print(ranges)

        // Read the images from the stream and decrypt them.
        var images: [Bytes] = []
        for range in ranges {
            print(range)
            print(stream.offset)
            let length = range.1 - range.0
            print(length)

            // TODO: Make this an extension!
            // TODO: Convert back to data here.
            // TODO: Can I just init Array(Data) and Data(Array)
            let imageData = try stream.read(count: Int(length))
            guard let image = imageData.withUnsafeBytes({ pointer in
                let bytes = Bytes(pointer)
                return sodium.box.open(anonymousCipherText: bytes,
                                       recipientPublicKey: keyPair.publicKey,
                                       recipientSecretKey: keyPair.secretKey)
            }) else {
                print("FAILED TO DECODE IMAGE")
                return
            }

            images.append(image)
        }

        // Iterate over the images coverting them from RLE.

        var frames: [NSImage] = []

        for image in images {
            let decoder = RLEDecoder(data: Data(image))
            let twoBitPerPixelData = try decoder.data()

            let panelStream = DataReadStream(data: twoBitPerPixelData)
            var values: [UInt8] = []
            while panelStream.hasBytesAvailable {
                let value: UInt8 = try panelStream.read()
                values.append(UInt8((value >> 0) & 3))
                values.append(UInt8((value >> 2) & 3))
                values.append(UInt8((value >> 4) & 3))
                values.append(UInt8((value >> 6) & 3))
            }

            var data = Data()
            for i in 0..<(Device.v1.width * Device.v1.height) {
                if i < values.count {
                    let value = values[i]
                    if value == 0 {
                        data.append(0)
                        data.append(0)
                        data.append(0)
                        data.append(255)
                    } else if value == 1 {
                        data.append(255)
                        data.append(255)
                        data.append(0)
                        data.append(255)
                    } else {
                        data.append(255)
                        data.append(255)
                        data.append(255)
                        data.append(255)
                    }
                } else {
                    data.append(255)
                    data.append(0)
                    data.append(255)
                    data.append(255)
                }
            }

            let dataProvider = CGDataProvider(data: data as NSData)!
            let cgImage = CGImage(width: Device.v1.width,
                                  height: Device.v1.height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: Device.v1.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: .byteOrderDefault,
                                  provider: dataProvider,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: .defaultIntent)!

            frames.append(NSImage(cgImage: cgImage, size: NSSize(width: Device.v1.width, height: Device.v1.height)))
        }

        DispatchQueue.main.sync {
            self.contents = frames[0]
            self.security = frames[1]
        }

    }

}

@main
struct StatusPanel_SimulatorApp: App {

    var applicationModel = ApplicationModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(applicationModel)
        }
    }

}
