//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/5/20.
//

import Foundation
import Combine


public protocol HTTPApi: API {
	static var apiBase: URL { get }
}


extension HTTPApi {
	func perform<T: Request>(request : T) -> AnyPublisher<T.Response, Error> {

		do {
			var httpRequest = URLRequest(url: Self.apiBase)

			try request.build(request: &httpRequest)

			let decoder = JSONDecoder()

			let dateFormatter = DateFormatter()
			dateFormatter.locale = Locale(identifier: "en_US_POSIX")
			dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
			decoder.dateDecodingStrategy = .formatted(dateFormatter)

			return URLSession.shared.dataTaskPublisher(for: httpRequest)
				.map { $0.data }
				.decode(type: T.Response.self, decoder: decoder) // Decode it
				.receive(on: RunLoop.main)
				.eraseToAnyPublisher()
		} catch {
			return Fail(outputType: T.Response.self, failure: error).eraseToAnyPublisher()
		}
	}
}
