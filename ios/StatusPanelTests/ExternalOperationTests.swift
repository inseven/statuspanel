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

import XCTest

@testable import StatusPanel

extension String {

    func asUrl() throws -> URL {
        guard let url = URL(string: self) else {
            throw StatusPanelError.invalidUrl
        }
        return url
    }

}

class ExternalOperationTests: XCTestCase {

    func testEquality() {
        XCTAssertEqual(Device(kind: .einkV1, id: "a", publicKey: "b"), Device(kind: .einkV1, id: "a", publicKey: "b"))
        XCTAssertNotEqual(Device(kind: .einkV1, id: "a", publicKey: "b"), Device(kind: .featherTft, id: "a", publicKey: "b"))
        XCTAssertNotEqual(Device(kind: .einkV1, id: "a", publicKey: "b"), Device(kind: .einkV1, id: "a", publicKey: "a"))

        XCTAssertEqual(ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b")),
                       ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b")))
        XCTAssertNotEqual(ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b")),
                          ExternalOperation.registerDevice(Device(kind: .einkV1, id: "b", publicKey: "b")))
        XCTAssertNotEqual(ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b")),
                          ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "c")))

        XCTAssertEqual(ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d"),
                       ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d"))
        XCTAssertNotEqual(ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d"),
                          ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "e"))
        XCTAssertNotEqual(ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d"),
                          ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "c", publicKey: "b"), ssid: "d"))

        XCTAssertNotEqual(ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b")),
                          ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d"))
    }

    func testRegisterDevice() throws {
        XCTAssertEqual(ExternalOperation(url: try "statuspanel:r?id=bob&pk=cheese".asUrl()),
                       ExternalOperation.registerDevice(Device(kind: .einkV1, id: "bob", publicKey: "cheese")))
    }

    func testRegisterDeviceAndConfigureWifi() throws {
        XCTAssertEqual(ExternalOperation(url: try "statuspanel:r?id=bob&pk=cheese&s=hi".asUrl()),
                       ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "bob", publicKey: "cheese"), ssid: "hi"))
    }

    func testUrlRoundTrip() {
        let operation1 = ExternalOperation.registerDevice(Device(kind: .einkV1, id: "a", publicKey: "b"))
        XCTAssertEqual(operation1, ExternalOperation(url: operation1.url))

        let operation2 = ExternalOperation.registerDeviceAndConfigureWiFi(Device(kind: .einkV1, id: "a", publicKey: "b"), ssid: "d")
        XCTAssertEqual(operation2, ExternalOperation(url: operation2.url))
    }

}
