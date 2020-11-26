//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/5/20.
//

import Foundation


public protocol HeaderToken: TokenProtocol {
	func toRequest() -> String
}

extension HeaderToken {

	public func authanticate(on request: inout URLRequest) {
		print("Authanticated with \(self.toRequest())")
		request.setValue("MTToken \(self.toRequest())", forHTTPHeaderField: "authorization")
	}
}
