//
//  TFLApi.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class TFLApi {
	// See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
	let app_id = "1f85b5bb"
	let app_key = "49b995489314995e79c9b4faa0d1d43c"

	// TODO genericise this
	func request(url: URL, onCompletion: @escaping (Any?, Error?) -> Void) {
		let session = URLSession.shared
		let task = session.dataTask(with: url) { (data: Data?, response: URLResponse?, err: Error?) in
			if let err = err {
				print("Error fetching \(url): \(err)")
				onCompletion(nil, err)
				return
			}
			guard let httpResponse = response as? HTTPURLResponse,
					httpResponse.statusCode == 200 else {
				print("Server errored! resp = \(response!)")
				let err = NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue, userInfo: ["response": response!])
				onCompletion(nil, err)
				return
			}
			do {
				let obj = try JSONSerialization.jsonObject(with: data!)
				onCompletion(obj, nil)
			} catch {
				print("Failed to decode obj from \(data!)")
				onCompletion(nil, error)
			}
		}
		task.resume()
	}

	func get(what: String, onCompletion: @escaping (Any?, Error?) -> Void) {
		let url = URL(string: "https://api.tfl.gov.uk/" + what + "?app_id=\(app_id)&app_key=\(app_key)")!
		request(url: url, onCompletion: onCompletion)
	}

}
