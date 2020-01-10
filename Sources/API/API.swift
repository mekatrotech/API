
import Foundation
import UserNotifications




public protocol API {
	static var shared: Self { get }
}

public extension API {
	@available(*, unavailable, message: "Please dont use any uninitialised stored properties on your api class")
	init() {
		fatalError()
	}
}

public struct Responce<Request> {
	var requestObject: Request
	var responceBody: Data
//
//	init(data: Data) throws {
//		self.responceBody = data
//		self.requestObject =
//	}
}

/*public extension API {

	// MARK:- Networking
	func perform<R: Request>(request: R, _ callback: @escaping ((APIResponce<R.Response>) -> ())) {

		do {
			var urlRequest = URLRequest(url: Self.apiBase.appendingPathComponent(request.path));

			if R.self is PostData {
				urlRequest.httpMethod = "POST"
				urlRequest.httpBody = try encode(request: request, urlRequest: &urlRequest)
			} else {
				urlRequest.httpMethod = "GET"
			}

			if R.self is LoginRequired {
				if case let .logged(_, token) = login {
					urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization");
				} else {
					callback(.failed(message: "Login Required", code: 0))
				}
			}

			let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { (data, responce, error) in
				if let data = data {
					let responce = Responce<R>(requestObject: request, responceBody: data)
					do {
						callback(try self.decode(responce: responce))
					} catch {
						callback(APIResponce<R.Response>.errored(error: error))
					}
				} else if let error = error {
					callback(APIResponce<R.Response>.errored(error: error))
				}
			})

			task.priority = 1.0
			task.resume()

		} catch {
			callback(APIResponce<R.Response>.errored(error: error))
		}
	}


}*/
