//
//  Created by Jesse Squires.
//  https://www.jessesquires.com
//
//  GitHub
//  https://github.com/jessesquires/ios-watchdog
//
//  Copyright © 2022-present Jesse Squires
//

import UIKit
import FirebaseCrashlytics

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}

extension UIViewController {
    var topPresentedViewController: UIViewController {
        if let topController = UIApplication.topViewController() {
            return topController
        }
        
        return self
    }
}

/// Watchdog implementation that logs excessive blocking on the main thread.
final public class Watchdog: NSObject, WatchdogRunLoopObserverDelegate {
    
    @objc
    public static let shared = Watchdog()

    private let observer = WatchdogRunLoopObserver()

    private var isStarted = false

//    @Inject private var reportsMediaUploader: IReportsMediaUploader
    
    override private init() {
        super.init()
        self.observer.delegate = self
    }

    deinit {
        stop()
    }

    public func start() {
        if isStarted {
            return
        }

        print("[Watchdog] started")
        observer.start()
        isStarted = true
    }

    public func stop() {
        print("[Watchdog] stopped")
        observer.stop()
    }

    // MARK: WatchdogRunLoopObserverDelegate

    public func runLoopDidStall(withDuration duration: TimeInterval) {
        
//        let activeUploadingsCount = reportsMediaUploader.getLoadableObjects().count
        
        var params: [String: Any] = [
            "blocking_time": duration
//            "uploadings_count": activeUploadingsCount
        ]
        
        if let topViewController = UIApplication.topViewController() {
            let topPresentedVc = topViewController.topPresentedViewController
            
            params["topmost_vc"] = String(describing: topPresentedVc)
        }
        
        #if !DEBUG
        Crashlytics.crashlytics().record(error: CommonError(text: "main thread blocked"), userInfo: params)
//        sendAnalytics(AnalyticsAction.Performance.mainThreadBlock, tags: params)
        #endif 
    }
}
