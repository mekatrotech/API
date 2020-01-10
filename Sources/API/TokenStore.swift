//
//  File.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/5/20.
//

import Foundation


public protocol TokenStorage {
	associatedtype User: UserProtocol
	
	init()
	
	func store(token: User.Token) -> Bool
	func retrive() -> User.Token?
}

