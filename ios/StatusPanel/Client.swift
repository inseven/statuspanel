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

}
