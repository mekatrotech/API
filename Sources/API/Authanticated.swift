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
public protocol Authanticated: HTTPApi {

	associatedtype Storage: TokenStorage // where Storage.Token == User.Token
	static var handler: LoginNotificationHandler<Self> { get }
	static var tokenStore: Storage { get }

	static var loginNotifications: Notification.Name { get }

	//	static func verify(token: Storage.Token) -> AnyPublisher<User, Never>
}


@available(iOS 13.0, *)
@available(OSX 10.15, *)
final class LoginSubscription<API: Authanticated, SubscriberType: Subscriber>: Subscription where SubscriberType.Input ==  Login<API.Storage.User> {
	internal init(subscriber: SubscriberType?) {
		self.subscriber = subscriber

		let f = self.subscriber!.receive(_:)


		API.handler.subs[self.myuuid] =  { i in
			_ = f(i) // LOL
		}
	}

	var myuuid = UUID()

	private var subscriber: SubscriberType?

	func request(_ demand: Subscribers.Demand) {
		// LOL Dont care
		print("Requested!")
	}

	func cancel() {
		API.handler.subs[self.myuuid] = nil
		print("Canceled")
	}
}
@available(iOS 13.0, *)
@available(OSX 10.15, *)
final class LoginPublisher<API: Authanticated>: Publisher {
	func receive<S>(subscriber: S) where S : Subscriber, LoginPublisher.Failure == S.Failure, LoginPublisher.Output == S.Input {
		subscriber.receive(subscription: LoginSubscription<API, S>(subscriber: subscriber))
	}

	typealias Output = Login<API.Storage.User>

	typealias Failure = Never


}

@available(iOS 13.0, *)
@available(OSX 10.15, *)
public class LoginNotificationHandler<MyAPI: Authanticated> {
	init() { }

	var currentLogin: Login<MyAPI.Storage.User> = .loggedout {
		didSet {
			self.publish()
		}
	}

	fileprivate(set) internal var loginRequest: AnyCancellable? = nil

	enum StorageError: Error {
		case cannotStore
	}

	func handleToken(token: MyAPI.Storage.User.Token) {
		if !MyAPI.tokenStore.store(token: token) {
			self.currentLogin = .errored(token: token, error: StorageError.cannotStore)
		}
		self.currentLogin = .validating(token: token)
		loginRequest?.cancel()
		loginRequest = MyAPI.shared.perform(request: token).sink(receiveCompletion: { (err) in
			// We have an error
			print("Error validating login!: \(err)")
			switch err {
			case .finished:
				break
			case .failure(let err):
				self.currentLogin = .errored(token: token, error: err)
			}

		}) { (myUser) in //
			// My user
			self.currentLogin = .logged(token: token, user: myUser)
		}
	}

	fileprivate var subs: [UUID: (Login<MyAPI.Storage.User>) -> ()] = [:]

	fileprivate func publish() {
		for i in self.subs {
			i.value(self.currentLogin)
		}
	}
}

@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension Authanticated {
	static var currentLogin: Login<Storage.User> {
		Self.handler.currentLogin
	}
}
@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension Authanticated {
	static func login(with token: Storage.User.Token) {
		Self.handler.handleToken(token: token)
	}

	static func start() {
		_ = Self.handler
		_ = Self.tokenStore


		// Check if we have a token
		if let token = Self.tokenStore.retrive() {
			print("We have a token!!")
			// Use it!

			Self.handler.handleToken(token: token)
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
	@available(iOS, introduced: 13.0)
	func perform<T: Request>(request: T) -> AnyPublisher<T.Response, APIError> {

		let encoder = JSONEncoder()

		do {
			let body = try encoder.encode(request)

			let url = Self.apiBase.appendingPathComponent(T.path)

			//			print(url)
			var request = URLRequest(url: url)

			request.httpMethod = "post"

			print("\(request.httpMethod!) Request to \(T.path):: \(url.absoluteString)")


			request.setValue("application/json", forHTTPHeaderField: "Content-Type")



			request.httpBody = body

			switch T.mode {
			case .required:
				if let token = Self.handler.currentLogin.getToken {
					request.setValue("MTToken \(token.toRequest())", forHTTPHeaderField: "Authorization")
				} else {
					fatalError()
				}
			case .optional:
				if let token = Self.handler.currentLogin.getToken {
					request.setValue("MTToken \(token.toRequest())", forHTTPHeaderField: "Authorization")
				}
			case .none:
				break
			}

			return URLSession.shared.dataTaskPublisher(for: request)
//				.print()
				.map { resp in print(String(data: resp.data, encoding: .utf8)!); return (resp.data) }
//				.map { $0.data }
				.decode(type: APIResponce<T>.self, decoder: JSONDecoder()) // Decode it
				.tryMap({ resp in
					switch resp {
					case .success(let data):
						return data
					case .failed(let message):
						throw APIError.returnedMessage(message: message)
					case .errored(let error):
						throw APIError.networkError(err: error)
					}
				})
				.receive(on: RunLoop.main)
				.mapError { APIError.networkError(err: $0) }
				.eraseToAnyPublisher()
		} catch {
			return Fail(outputType: T.Response.self, failure: APIError.networkError(err: error)).eraseToAnyPublisher()
		}
	}
}
