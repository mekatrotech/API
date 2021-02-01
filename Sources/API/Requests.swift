//
//  Requests.swift
//  API
//
//  Created by Muhammet Mehmet Emin Kartal on 6/16/19.
//

import Foundation
import Combine

public protocol Previewable {
	static var PreviewValue: Self { get }
}


extension Array: Previewable where Element: Previewable {
	public static var PreviewValue: Array<Element> {
		return [Element.PreviewValue, Element.PreviewValue, Element.PreviewValue, Element.PreviewValue]
	}
}

public enum HTTPMethod: String {
	case get
	case post
	case put
}

public protocol Request {
	associatedtype Base: API
	associatedtype Response: (Codable & Previewable) = EmptyResponse
	static var mode: LoginMode { get }
	static var path: String { get }

	func build(request: inout URLRequest) throws
//	func decode(response: Data) -> Response
}

extension Request {
	static var mode: LoginMode { .none }
}


public protocol PostRequest: Request where Base: HTTPApi, Self: Codable { }
public protocol GetRequest: Request where Base: HTTPApi { }
public protocol LoginRequired: Request { }

extension LoginRequired {
	static var mode: LoginMode { .required }
}

extension GetRequest {
	public func build(request: inout URLRequest) throws {
//		let encoder = JSONEncoder()
		request.httpMethod = "get"
		request.url = Self.Base.apiBase.appendingPathComponent(Self.path)
//		request.httpBody = try encoder.encode(self)
//		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
	}
}
extension PostRequest {
	public func build(request: inout URLRequest) throws {
		let encoder = JSONEncoder()
		request.url = Self.Base.apiBase.appendingPathComponent(Self.path)
		request.httpMethod = "post"
		request.httpBody = try encoder.encode(self)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
	}
}
public extension Request where Base: HTTPApi {
	func perform() -> AnyPublisher<Self.Response, Error> {
		return Base.shared.perform(request: self)
	}
}



public protocol TokenProtocol: Request, Equatable {
	associatedtype User: UserProtocol
	func authanticate(on request: inout URLRequest)
	static func getUser(from: Self.Response) -> Result<User, Error>
}


public protocol UserProtocol where Token.User == Self {
	associatedtype Token: TokenProtocol, Codable
}

//public protocol LoginProvider: Request, PostData where Response: TokenProtocol { }


public protocol IdEquatable: Equatable {
	var id: Int { get }
	static func == (lhs: Self, rhs: Self) -> Bool
}

public extension IdEquatable {
	static func == (lhs: Self, rhs: Self) -> Bool { return lhs.id == rhs.id }
}

public typealias Coquatable = Codable & Equatable

/// Root object that returns from the API
public enum APIResponce<T: Codable>: Codable {

	/// When request is successful
	case success(data: T)
	/// When the server responded with failure message
	case failed(message: String)
	/// When other errors occur (Network connectivity etc..)
	case errored(error: Error)

	enum PostTypeCodingError: Error {
		case decoding(String)
		case encoding(String)
	}

	private enum CodingKeys: String, CodingKey {
		case success
		case failed
	}

	public init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)


		if let value = try? values.decode(String.self, forKey: .failed) {
			self = .failed(message: value)
			return
		}
		self = .success(data: try values.decode(T.self, forKey: .success))
	}

	public func encode(to encoder: Encoder) throws {
		throw PostTypeCodingError.encoding("NOT Supported yet")
	}
}

extension APIResponce: Previewable where T: Previewable {
	public static var PreviewValue: APIResponce<T> {
		return .success(data: T.PreviewValue)
	}
}

public struct EmptyResponse: Codable, Previewable {
	public static var PreviewValue: EmptyResponse = EmptyResponse()
}


public enum LoginMode {
	case required
//	case optional
	case none
}


//public protocol LoginRequired { }
public protocol PostData: Encodable { }


public struct EmptyResponce: Codable { }

