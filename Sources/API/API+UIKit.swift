//
//  API+UIKit.swift
//  API
//
//  Created by Muhammet Mehmet Emin Kartal on 6/16/19.
//

#if os(iOS)
import UIKit
import Foundation

public extension API {

	func apiAlert(_ title: String, message: String, _ settings: Bool = false) {
		let vc = UIAlertController(title: title, message: message, preferredStyle: .alert);
		
		vc.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
		if settings {
			let s = URL(string: UIApplication.openSettingsURLString)!
			if UIApplication.shared.canOpenURL(s) {
				vc.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (_) in

					if #available(iOS 10.0, *) {
						UIApplication.shared.open(s, options: [:], completionHandler: { (_) in })
					} else {
						// Fallback on earlier versions
					}
				}))
			}
		}
		DispatchQueue.main.async {
			let alertWindow = UIWindow(frame: UIScreen.main.bounds)
			alertWindow.rootViewController = UIViewController();
			alertWindow.windowLevel = .alert
			alertWindow.makeKeyAndVisible()
			alertWindow.rootViewController?.present(vc, animated: true, completion: nil);
		}

		//
		//		alerts.append(vc);
		//		NotificationCenter.default.post(name: mekatroteknoAPIAlertNotification, object: nil);
	}

}
#else

#endif
