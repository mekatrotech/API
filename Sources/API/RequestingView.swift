//
//  RequestingView.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 7/1/20.
//

import SwiftUI
import Combine


public struct RequestSimulating: EnvironmentKey {
	public static var defaultValue: Int? = nil
}

public extension View {
	func button(action: @escaping () -> Void) -> some View {
		Button(action: action, label: { self })
	}
}

public extension EnvironmentValues {
	var simulatingUser: Int? {
		get {
			return self[RequestSimulating.self]
		}
		set {
			self[RequestSimulating.self] = newValue
		}
	}
}


public struct Simulating<R: HTTPRequest>: HTTPRequest where R.Base: Authanticated {

	public func build(request: inout URLRequest) throws {
		request.setValue("\(user)", forHTTPHeaderField: "x-user")
		try self.simulating.build(request: &request)
	}

	public typealias Base = R.Base
	public static var mode: LoginMode  { R.mode }
	public static var path: String { R.path }
	public typealias Response = R.Response

	public var simulating: R
	public var user: Int

	public init(_ simulating: R, on user: Int) {
		self.simulating = simulating
		self.user = user
	}
}

extension Notification.Name {
	static var requestUpdateNotification = Notification.Name("requestUpdateNotification")
}

public func updateRequesting(identifier: String, clean: Bool = false) {
	print("Requesting update for \(identifier)")
	NotificationCenter.default.post(name: .requestUpdateNotification, object: nil, userInfo: ["requestingUpdateIdentifier": identifier, "clean": clean])
}

public struct RequestingView<R: HTTPRequest, Content>: View where Content: View, R.Base : Authanticated {

	@Environment(\.simulatingUser) var simulatingUser: Int?

	public init(_ request: R, details: TaskManager.Task.Details? = nil, updateIdentifier: String = "", @ViewBuilder content: @escaping (_ response:  R.Response) -> Content) {
		self.details = details ?? TaskManager.Task.Details(name: "Loading", image: "hexagon.fill", color: .green, shouldPause: false)
		self.request = request
		self.updateIdentifier = updateIdentifier
		self.content = content
	}

	var details: TaskManager.Task.Details
	var request: R
	var updateIdentifier: String = ""

	@State var responce: R.Response?
	@State var error: String?
	@State private var urlRequest: Combine.AnyCancellable?

	var content: ( R.Response) -> Content

	public var body: some View {

		VStack {

			if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
				content( R.Response.PreviewValue)
			} else {
				if let responce = self.responce {
					content(responce)
				} else if let error = self.error  {
					VStack {
						Text("Error \n \(error)")
							.multilineTextAlignment(.leading)
							.lineLimit(0)
							.padding()
						Text("Retry")
							.button {
								self.requestStart()
							}
					}
				} else {
					VStack {
						if #available(iOS 14.0, *) {
							ProgressView() {
								Text("Loading!")
							}
						} else {
							Text("Loading!")
						}
					}
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .requestUpdateNotification), perform: { (output) in
			if let name = output.userInfo?["requestingUpdateIdentifier"] as? String {
				if name == self.updateIdentifier {
					if let clean = output.userInfo?["clean"] as? Bool, clean {
						self.urlRequest?.cancel()
						self.responce = nil
						self.requestStart()
					} else {
						self.urlRequest?.cancel()
						self.requestStart()
					}
				}
			}
		})
		.onDisappear(perform: {
			self.urlRequest?.cancel()
		})
		.onAppear {
			self.requestStart()
		}
	}

	func requestStart() {
		if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
			return;
		}
		self.urlRequest?.cancel()
		if let user = simulatingUser {
			self.urlRequest = Simulating(self.request, on: user)
				.perform()
				.manage(details: details)
				.sink(receiveCompletion: { (error) in
					if case .failure(let error) = error {
						withAnimation {
							self.error = error.localizedDescription
						}
					}
				}, receiveValue: { (response) in
					withAnimation {
						self.responce = response
					}
				})
		} else {
			self.urlRequest = self.request
				.perform()
				.manage(details: details)
				.sink(receiveCompletion: { (error) in
					if case .failure(let error) = error {
						withAnimation {
							self.error = error.localizedDescription
						}
					}
				}, receiveValue: { (response) in
					withAnimation {
						self.responce = response
					}
				})
		}
	}
}

//@available(iOS 14.0, *)
//@available(OSX 10.16, *)
//struct RequestingLibrary: LibraryContentProvider {
//	@LibraryContentBuilder
//
//	var views: [LibraryItem]  {
//		LibraryItem(RequestingView(TestRequest()) { response in
//
//		})
//	}
//}
