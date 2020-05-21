//
//  File 2.swift
//  
//
//  Created by Muhammet Mehmet Emin Kartal on 5/21/20.
//

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0, *)
struct TaskManagerKey: EnvironmentKey {
	static let defaultValue: TaskManager = TaskManager()
}

@available(iOS 13.0, *)
public class TaskManager: ObservableObject {
	init() {

	}

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
			print("Updated task: \(self.tasks[index])")
		}

		var pause = false
		for task in tasks {
			if task.status != .ended || task.status != .canceled {
				if task.details.shouldPause {
					pause = true
					break
				}
			}
		}
		if self.pause != pause {
			self.pause = pause
		}
	}

	@Published var tasks: [Task] = []

	@Published var pause: Bool = false

	public struct Task: Identifiable {
		public var id: UUID = UUID()
		public var details: Details
		public var status: TaskStatus = .created
		public enum TaskStatus: String {
			case created
			case subscribed
			case hasInput
			case ended
			case canceled
		}

		public struct Details {
			var name: String
			var image: String = "timer"
			var color: UIColor = .red
			var shouldPause = false
		}
	}
}

@available(iOS 13.0, *)
extension EnvironmentValues {
	var taskManager: TaskManager {
		get {
			return self[TaskManagerKey.self]
		}
		set {
			self[TaskManagerKey.self] = newValue
		}
	}
}

@available(iOS 13.0, *)
extension Publisher {
	func manage(using manager: TaskManager, details: TaskManager.Task.Details) -> ManagedPublisher<Self> {
		return ManagedPublisher(upstream: self, manager: manager, details: details)
	}
}

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
		Swift.print("Registering new task")
	}

	public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
		upstream.receive(subscriber: ManagerSubscriber(taskID: id, manager: self.manager))
		upstream.receive(subscriber: subscriber)
	}

	class ManagerSubscriber<Input, Failure: Error>: Subscriber {
		var combineIdentifier: CombineIdentifier = .init()
		var taskID: UUID
		var manager: TaskManager

		public init(taskID: UUID, manager: TaskManager) {
			self.taskID = taskID
			self.manager = manager
		}

		var sub: Subscription?

		func receive(subscription: Subscription) {
			self.manager.update(task: self.taskID, new: .subscribed)
			subscription.request(.unlimited)
		}

		func receive(_ input: Input) -> Subscribers.Demand {
			self.manager.update(task: self.taskID, new: .hasInput)
			return .max(1)
		}

		func receive(completion: Subscribers.Completion<Failure>) {
			self.manager.update(task: self.taskID, new: .ended)
		}

		deinit {
			self.manager.update(task: self.taskID, new: .canceled)
		}
	}
}