
import Foundation
import UserNotifications




public protocol API {
	static var shared: Self { get }
}

public extension API {
	@available(*, unavailable, message: "Please don't use any uninitialised stored properties on your api class")
	init() {
		fatalError()
	}
}

public struct Responce<Request> {
	var requestObject: Request
	var responceBody: Data
}
