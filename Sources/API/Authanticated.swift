//
//  File.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/5/20.
//

import Foundation
import Combine

@available(iOS 13.0, *)
@available(OSX 10.15, *)
@available(watchOS 6.0, *)
public protocol Authanticated: HTTPApi {

	associatedtype Storage: TokenStorage // where Storage.Token == User.Token
	static var tokenHandler: LoginNotificationHandler<Self> { get }
	static var tokenStore: Storage { get }

}


@available(watchOS 6.0, *)
@available(iOS 13.0, *)
@available(OSX 10.15, *)
public final class LoginSubscription<API: Authanticated, SubscriberType: Subscriber>: Subscription where SubscriberType.Input ==  Login<API.Storage.User> {
	internal init(subscriber: SubscriberType?) {
		self.subscriber = subscriber

		let f = self.subscriber!.receive(_:)


		API.tokenHandler.subs[self.myuuid] =  { i in
			_ = f(i) // LOL
		}
	}

	var myuuid = UUID()

	private var subscriber: SubscriberType?

	public func request(_ demand: Subscribers.Demand) {
		// LOL Dont care
		print("Requested!")
	}

	public func cancel() {
		API.tokenHandler.subs[self.myuuid] = nil
		print("Canceled")
	}
}
@available(watchOS 6.0, *)
@available(iOS 13.0, *)
@available(OSX 10.15, *)
public final class LoginPublisher<API: Authanticated>: Publisher {
	public func receive<S>(subscriber: S) where S : Subscriber, LoginPublisher.Failure == S.Failure, LoginPublisher.Output == S.Input {
		subscriber.receive(subscription: LoginSubscription<API, S>(subscriber: subscriber))
	}

	public typealias Output = Login<API.Storage.User>

	public typealias Failure = Never


}

@available(watchOS 6.0, *)
@available(iOS 13.0, *)
@available(OSX 10.15, *)
public class LoginNotificationHandler<MyAPI: Authanticated> {
	public init() { }

	var currentLogin: Login<MyAPI.Storage.User> = .loggedout {
		didSet {
			self.publish()
		}
	}

	fileprivate(set) internal var loginRequest: AnyCancellable? = nil

	enum StorageError: Error {
		case cannotStore
		case cannotDelete
	}

	func handleToken(token: MyAPI.Storage.User.Token) {
		if !MyAPI.tokenStore.store(token: token) {
			self.currentLogin = .errored(token: token, error: StorageError.cannotStore)
		}
		self.currentLogin = .validating(token: token)
		loginRequest?.cancel()
		loginRequest = MyAPI.shared.perform(request: token)
			.manage(details: .init(name: "Validating Login", image: "personalhotspot", color: .yellow, shouldPause: true))
			.sink { error in
				if case .failure(let error) = error {
					self.currentLogin = .errored(token: token, error: error)
				}
			} receiveValue: { response in
				let result = MyAPI.Storage.User.Token.getUser(from: response)
				switch result {
				case .success(let user):
					self.currentLogin = .logged(token: token, user: user)
				case .failure(let error):
					self.currentLogin = .errored(token: token, error: error)
				}

			}
	}

	func releaseToken() {
		guard let token = self.currentLogin.getToken else {
			return
		}

		if MyAPI.tokenStore.release() {
			self.currentLogin = .loggedout
		} else {
			self.currentLogin = .errored(token: token , error: StorageError.cannotDelete)
		}
	}
	fileprivate var subs: [UUID: (Login<MyAPI.Storage.User>) -> ()] = [:]

	fileprivate func publish() {
		for i in self.subs {
			i.value(self.currentLogin)
		}
	}
}

@available(watchOS 6.0, *)
@available(iOS 13.0, *)
@available(OSX 10.15, *)
public extension Authanticated {
	static var currentLogin: Login<Storage.User> {
		Self.tokenHandler.currentLogin
	}
}
@available(watchOS 6.0, *)
@available(iOS 13.0, *)
@available(OSX 10.15, *)
public extension Authanticated {
	static func login(with token: Storage.User.Token) {
		Self.tokenHandler.handleToken(token: token)
	}

	static func logout() {
		Self.tokenHandler.releaseToken()
	}

	static func start() {
		_ = Self.tokenHandler // Init
		_ = Self.tokenStore


		// Check if we have a token
		if let token = Self.tokenStore.retrive() {
			print("We have a token!!")
			// Use it!

			Self.tokenHandler.handleToken(token: token)
		} else {
			print("We dont have any tokens!")
		}
	}


	func publisher() -> LoginPublisher<Self> {
		return LoginPublisher<Self>()
	}
}

public enum APIError: Error {
	case returnedMessage(message: String)
	case networkError(err: Error)
	case stillRequesting
}

@available(iOS 13.0, *)
@available(OSX 10.15, *)
@available(watchOS 6.0, *)
public extension Authanticated  {


	//	static func perform(request: Request) -> AnyPi {
	//
	//	}
	//
	//	enum APIError: Error {
	//		case returnedMessage(message: String)
	//		case networkError(err: Error)
	//		case stillRequesting
	//	}



	/// Performs the request object
	/// Don't forget to store the returning value or request will be canceled!
	/// - Parameter request: Requesting object

	func perform<T: Request>(request : T) -> AnyPublisher<T.Response, Error> {

		do {
			var httpRequest = URLRequest(url: Self.apiBase)

			try request.build(request: &httpRequest)

			switch T.mode {
			case .required:
				Self.tokenHandler.currentLogin.getToken!.authanticate(on: &httpRequest)
			case .none:
				break
			}

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

	
	@available(iOS, introduced: 13.0, obsoleted: 14.0, renamed: "perform(request:)")
	func perform<T: Request>(request: T, callback: @escaping (T.Response?) -> ()) {

		do {
			var httpRequest = URLRequest(url: Self.apiBase.appendingPathComponent(T.path))
			try request.build(request: &httpRequest)



			switch T.mode {
			case .required:
				Self.tokenHandler.currentLogin.getToken!.authanticate(on: &httpRequest)
			case .none:
				break
			}


			return URLSession.shared.dataTask(with: httpRequest, completionHandler: { (data, resp, err) in
				if let data = data {

					print("DBG: APIResp: \(String(data: data, encoding: .utf8)!)")
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .secondsSince1970
					decoder.dataDecodingStrategy = .base64

					if case let .success(data) = try? decoder.decode(APIResponce<T.Response>.self, from: data) {
						callback(data)
					} else {
						callback(nil)
					}
				}

				if err != nil {
					callback(nil)
				}
			})
			.resume()
		} catch {
			callback(nil)
		}
	}
}
