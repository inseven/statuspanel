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

class JSONRequest {

    // TODO: Does anything inject the session?
    static func makeRequest<T>(url: URL, session: URLSession? = nil, onCompletion: @escaping (T?, Error?) -> Void) -> URLSessionDataTask where T : Decodable {
        let session = session ?? URLSession.shared
        let task = session.dataTask(with: url) { (data: Data?, response: URLResponse?, err: Error?) in
            if let err = err {
                print("Error fetching \(url): \(err)")
                onCompletion(nil, err)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let data = data
                else {
                    print("Server errored! resp = \(response!)")
                    let err = NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue, userInfo: ["response": response!])
                    onCompletion(nil, err)
                    return
            }
            do {
                let obj = try JSONDecoder().decode(T.self, from: data)
                onCompletion(obj, nil)
            } catch {
                print("Failed to decode obj from \(data)")
                onCompletion(nil, error)
            }
        }
        task.resume()
        return task
    }
}

