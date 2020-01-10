//
//  LoginManager.swift
//  API
//
//  Created by Muhammet Mehmet Emin Kartal on 6/16/19.
//

import Foundation

public enum Login<User: UserProtocol> {
	case logged(token: User.Token, user: User)
	case validating(token: User.Token)
	case errored(token: User.Token, error: Error)
	case loggedout


	var getToken: User.Token? {
		switch self {
		case .logged(let token, _):
			return token
		case .validating(let token):
			return token
		case .errored(let token, _):
			return token
		case .loggedout:
			return nil
		}
	}
}

/*
public extension API {
	func start() {

	}

	func loginUser<R: LoginProvider>(with request: R, responce: @escaping (Login<User, Token>) -> ()) where R.Response == Token {

	}

	func validateUser() {
		assert(!Thread.isMainThread)

		if case .loggedout = self.login {

		}
		guard let token = self.login.getToken else {
			return
		}

		self.perform(request: User.Validator()) { (responce) in
			switch responce {
			case .success(let data):
				self.login = Login<User, Token>.logged(token: token, user: data as! User)
			case .failed(_, _): break

			case .errored(let error):
				self.login = Login<User, Token>.errored(token: token, error: error)
			}
		}
	}

	func encode<R: Request>(request: R, urlRequest: inout URLRequest) throws -> Data {
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type");


		let encoder = JSONEncoder()
		return try encoder.encode(request)
	}

	func decode<R: Request>(responce: Responce<R>) throws -> APIResponce<R.Response> {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.dataDecodingStrategy = .base64

		return try decoder.decode(DataErrorAPIResponceDecoder<R.Response>.self, from: responce.responceBody).responce
	}

}




*/
