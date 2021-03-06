//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 5/21/20.
//

import Foundation
import SwiftUI
import Combine


@available(watchOS 6.0, *)
@available(iOS 13.0, *)
public class TaskManager: ObservableObject {
	@available(*, unavailable)
	init() {

	}

	private init(privateinit: ()) {

	}

	var forgetTasks: [UUID: AnyCancellable] = [:]

	static public var shared = TaskManager(privateinit: ())

	func update(task id: UUID, new status: Task.TaskStatus) {
		if let index = self.tasks.lastIndex(where: {$0.id == id}) {
			if self.tasks[index].status != .ended {
				self.tasks[index].status = status
			}

			if status == .ended {

				Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { (_) in
					if let index = self.tasks.lastIndex(where: {$0.id == id}) {
						self.tasks.remove(at: index)
					}
				}
			}
//			print("Updated task: \(self.tasks[index])")
		}

		var pause = false
		for task in tasks {
			if task.status == .created && task.details.shouldPause {
				print("Task with id '\(task.id)' is pausing screen")
				pause = true
				break
			}
		}
		if self.pause != pause {
//			print("Set Pause: \(pause)")
			self.pause = pause
		}
	}

	@Published public var tasks: [Task] = []

	@Published public var pause: Bool = false
	@Published public var message: String? = nil

	public struct Task: Identifiable {
		public var id: UUID = UUID()
		public var details: Details
		public var status: TaskStatus = .created
		public enum TaskStatus: String {
			case created
//			case subscribed
//			case hasInput
			case ended
//			case canceled
		}

		public struct Details {
			public init(name: String, image: String = "timer", color: Color = .red, shouldPause: Bool = false) {
				self.name = name
				self.image = image
				self.color = color
				self.shouldPause = shouldPause
			}

			public var name: String
			public var image: String = "timer"
			public var color: Color = .red
			public var shouldPause = false
		}
	}
}

@available(watchOS 6.0, *)
@available(iOS 13.0, *)
extension Publisher {
	public func manage(details: TaskManager.Task.Details) -> ManagedPublisher<Self> {

		return ManagedPublisher(upstream: self, manager: TaskManager.shared, details: details)
	}

	public func forget<R: Codable>(with details: TaskManager.Task.Details,  callback: (()->())? = nil ) where Self.Output == APIResponce<R>, Self.Failure == Never {

		let task = TaskManager.Task(details: details)
		TaskManager.shared.tasks.append(task)

		TaskManager.shared.forgetTasks[task.id] = self.sink { (resp) in
			TaskManager.shared.update(task: task.id, new: .ended)

			switch resp {
			case .success(_):
				callback?()
				break
			case .failed(message: let message):
				TaskManager.shared.message = message
			case .errored(error: let error):
				TaskManager.shared.message = error.localizedDescription
			}
			TaskManager.shared.forgetTasks[task.id] = nil
		}
	}
}

@available(watchOS 6.0, *)
@available(iOS 13.0, *)
public class ManagedPublisher<Upstream>: Publisher where Upstream: Publisher {

	/// The kind of values published by this publisher.
	public typealias Output = Upstream.Output

	/// The kind of errors this publisher might publish.
	///
	/// Use `Never` if this `Publisher` does not publish errors.
	public typealias Failure = Upstream.Failure

	/// The publisher from which this publisher receives elements.
	public let upstream: Upstream
	public let manager: TaskManager
	public let details: TaskManager.Task.Details
	public let id: UUID

	public init(upstream: Upstream, manager: TaskManager, details: TaskManager.Task.Details) {
		self.upstream = upstream
		self.manager = manager
		self.details = details

		let task = TaskManager.Task(details: details)
		self.id = task.id
		self.manager.tasks.append(task)
		self.manager.update(task: self.id, new: .created)
//		Swift.print("Registering new task")
	}

	public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
		upstream.receive(subscriber: ManagerSubscriber(downstream: subscriber, taskID: id, manager: self.manager))
//		upstream.receive(subscriber: subscriber)
	}

	class ManagerSubscriber<Downstream: Subscriber>: Subscriber where Downstream.Input == Output, Downstream.Failure == Upstream.Failure {

        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
		var combineIdentifier: CombineIdentifier = .init()
		var taskID: UUID
		var manager: TaskManager

		public init(downstream: Downstream, taskID: UUID, manager: TaskManager) {
			self.taskID = taskID
			self.downstream = downstream
			self.manager = manager
		}

		var sub: Subscription?

		func receive(subscription: Subscription) {
//			self.manager.update(task: self.taskID, new: .subscribed)
//			subscription.request(.unlimited)
			downstream.receive(subscription: subscription)
		}

		func receive(_ input: Input) -> Subscribers.Demand {
//			self.manager.update(task: self.taskID, new: .hasInput)
			return downstream.receive(input)
//			return .max(1)
		}

		func receive(completion: Subscribers.Completion<Failure>) {
			downstream.receive(completion: completion)
			self.manager.update(task: self.taskID, new: .ended)
		}

		deinit {
			self.manager.update(task: self.taskID, new: .ended)
		}
	}
}
