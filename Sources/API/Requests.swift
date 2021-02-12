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

	func build(request: inout URLRequest) throws
	func decode(response: Data) -> Response
}

extension Request {
	static var mode: LoginMode { .none }
}

public protocol HTTPRequest: Request where Base: HTTPApi {
	static var path: HTTPPath<Self> { get }
}

public struct HTTPPath<T: HTTPRequest>: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
	public var description: String {
		self.path
	}

	public struct StringInterpolation<T: HTTPRequest>: StringInterpolationProtocol {
		// start with an empty string
		var output = ""
		var variables: [String: KeyPath<T, String>] = [:]

		// allocate enough space to hold twice the amount of literal text
		public init(literalCapacity: Int, interpolationCount: Int) {
			output.reserveCapacity(literalCapacity * 2)
			variables.reserveCapacity(interpolationCount)
		}

		// a hard-coded piece of text – just add it
		public mutating func appendLiteral(_ literal: String) {
			print("Appending \(literal)")
			output.append(literal)
		}

		// a Twitter username – add it as a link
		public mutating func appendInterpolation(named name: String, _ path: KeyPath<T, String>) {
			output.append(":\(name)")
			self.variables[name] = path
		}
	}

	// the finished text for this whole component
	public let path: String
	public let variables: [String: KeyPath<T, String>]

	// create an instance from a literal string
	public init(stringLiteral value: String) {
		self.path = value
		variables = [:]
	}

	// create an instance from an interpolated string
	public init(stringInterpolation: StringInterpolation<T>) {
		path = stringInterpolation.output
		variables = stringInterpolation.variables
	}

	func build(with object: T) -> String {
		if self.variables.count == 0 {
			return self.path
		}
		var output = self.path
		for i in self.variables {
			output = output.replacingOccurrences(of: ":\(i.key)", with: object[keyPath: i.value])
		}
		return output
	}
}

public protocol PostRequest: HTTPRequest where Self: Codable {
//	static var Encoder: JSONEncoder { get }
}
public protocol GetRequest: HTTPRequest { }
public protocol LoginRequired: Request { }

extension LoginRequired {
	static var mode: LoginMode { .required }
}

extension GetRequest {
	public func build(request: inout URLRequest) throws {
//		let encoder = JSONEncoder()
		request.httpMethod = "get"
		request.url = Self.Base.apiBase.appendingPathComponent(Self.path.build(with: self))
//		request.httpBody = try encoder.encode(self)
//		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
	}
}
extension PostRequest {
	static var Encoder: JSONEncoder {
		let encoder = JSONEncoder()
		return encoder
	}

	public func build(request: inout URLRequest) throws {
		request.url = Self.Base.apiBase.appendingPathComponent(Self.path.build(with: self))
		request.httpMethod = "post"
		request.httpBody = try Self.Encoder.encode(self)
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

