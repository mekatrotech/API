//
//  Requests.swift
//  API
//
//  Created by Muhammet Mehmet Emin Kartal on 6/16/19.
//

import Foundation


public protocol Request: Codable {
	associatedtype Response: Codable = EmptyResponse
	static var mode: LoginMode { get }
	static var path: String { get }
}



public protocol TokenProtocol: Request, Equatable where Response: UserProtocol {
	func toRequest() -> String
}


public protocol UserProtocol where Token.Response == Self {
	associatedtype Token: TokenProtocol
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
public enum APIResponce<T: Request>: Codable {

	/// When request is successful
	case success(data: T.Response)
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

		if let value = try? values.decode(T.Response.self, forKey: .success) {
			self = .success(data: value)
			return
		}

		 throw PostTypeCodingError.decoding("No success of failed found in responce")
	}

	public func encode(to encoder: Encoder) throws {
		throw PostTypeCodingError.encoding("NOT Supported yet")
	}
}


public struct EmptyResponse: Codable {

}


public enum LoginMode {
	case required
	case optional
	case none
}


public protocol LoginRequired { }
public protocol PostData: Encodable { }


public struct EmptyResponce: Codable { }

