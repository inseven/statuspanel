//
//  TFLApi.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 08/09/2018.
//  Copyright © 2018 Tom Sutcliffe. All rights reserved.
//

import Foundation

class TFLApi : DataSource {
	// See https://api-portal.tfl.gov.uk/admin/applications/1409617922524
	let app_id = "1f85b5bb"
	let app_key = "49b995489314995e79c9b4faa0d1d43c"

	var linesOfInterest = ["northern", "central"]
	var dataItems = [DataItem]()

	// TODO genericise this
	static func jsonRequest<T>(url: URL, onCompletion: @escaping (T?, Error?) -> Void) where T : Decodable {
		let session = URLSession.shared
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
	}

	func get<T>(_ what: String, onCompletion: @escaping (T?, Error?) -> Void) where T : Decodable {
		let sep = what.contains("?") ? "&" : "?"
		let url = URL(string: "https://api.tfl.gov.uk/" + what + sep + "app_id=\(app_id)&app_key=\(app_key)")!
		TFLApi.jsonRequest(url: url, onCompletion: onCompletion)
	}

	func getData() {
		let lines = linesOfInterest.joined(separator: ",")
		get("Line/\(lines)/Status?detail=false", onCompletion: gotLineData)
	}

	struct LineStatus: Decodable {
		var name: String
		var lineStatuses: [LineStatusItem]

		struct LineStatusItem: Codable {
			var statusSeverity: Int
			var statusSeverityDescription: String
		}
	}

	func gotLineData(data: [LineStatus]?, err: Error?) {
		dataItems = []
		for line in data ?? [] {
			if line.lineStatuses.count < 1 {
				continue
			}
			let desc = line.lineStatuses[0].statusSeverityDescription
			let sev = line.lineStatuses[0].statusSeverity
			var flags: Set<DataItemFlag> = []
			if sev < 10 {
				flags.insert(.warning)
			}
			dataItems.append(DataItem("\(line.name): \(desc)", flags: flags))
		}
		print(dataItems)
	}
}
