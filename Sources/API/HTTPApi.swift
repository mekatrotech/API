//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 1/5/20.
//

import Foundation


public protocol HTTPApi: API {
	static var apiBase: URL { get }
}
