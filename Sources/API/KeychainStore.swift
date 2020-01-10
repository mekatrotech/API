//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/9/20.
//

import Foundation
import KeychainAccess

public final class KeychainStorageProvider<User: UserProtocol>: TokenStorage {

	let keychain = Keychain(service: "com.my.api.secrets").synchronizable(false);



	func retrive() -> User.Token? {

		guard let storage = try? keychain.getData("tokenStorage") else {
			return nil
		}

		return try? JSONDecoder().decode(User.Token.self, from: storage)
	}

	func store(token: User.Token) -> Bool {

		guard let data = try? JSONEncoder().encode(token) else {
			return false
		}

		do {
			try keychain.set(data, key: "tokenStorage")
			return true
		} catch {
			return false
		}
	}

	public init() {
		print("Keychain Module initialised!")
	}
}

