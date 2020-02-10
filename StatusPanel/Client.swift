//
//  Client.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 04/02/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

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
