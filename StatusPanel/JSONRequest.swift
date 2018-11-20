//
//  JSONRequest.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 15/10/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class JSONRequest {

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

