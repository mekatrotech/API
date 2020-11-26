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
		loginRequest = MyAPI.shared.perform(request: token).manage(details: .init(name: "Validating Login", image: "personalhotspot", color: .yellow, shouldPause: true)).sink(receiveValue: { (resp) in
			switch resp {

			case .success(data: let myUser):
				self.currentLogin = .logged(token: token, user: myUser)
			case .failed(message: let message):
				self.currentLogin = .errored(token: token, error: APIError.returnedMessage(message: message))
			case .errored(error: let error):
				self.currentLogin = .errored(token: token, error: error)
			}
		})
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


	@available(iOS, introduced: 13.0, deprecated: 14.0, obsoleted: 14.1)
	func perform<T: Request>(request : T) -> AnyPublisher<APIResponce<T.Response>, Never> {

		let encoder = JSONEncoder()

		do {

			var httpRequest = URLRequest(url: Self.apiBase.appendingPathComponent(T.path))

			try request.build(request: &httpRequest)

			switch T.mode {
			case .required:
				Self.tokenHandler.currentLogin.getToken!.authanticate(on: &httpRequest)
			case .none:
				break
			}

			return URLSession.shared.dataTaskPublisher(for: httpRequest)
				//				.print()
				.map { resp in print(String(data: resp.data, encoding: .utf8)!); return (resp.data) }
				//				.map { $0.data }
				.decode(type: APIResponce<T.Response>.self, decoder: JSONDecoder()) // Decode it
				.catch({ err in
					Just(APIResponce<T.Response>.errored(error: err))
				})
				.receive(on: RunLoop.main)
//				.mapError { APIError.networkError(err: $0) }
				.eraseToAnyPublisher()
		} catch {
			return Just(APIResponce<T.Response>.errored(error: error)).eraseToAnyPublisher()
		}
	}

	
	@available(iOS, introduced: 13.0, obsoleted: 14.0)
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
