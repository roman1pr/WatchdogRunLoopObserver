//
//  MemoryReporter.swift
//  Rebotics
//
//  Created by Andrei Kileev on 07.06.2023.
//

import Foundation
import FirebaseCrashlytics

func printToConsole(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let presenter = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(presenter, terminator: terminator)
    #endif
}

public class DevicePressureLogger {
    
    public static let shared = DevicePressureLogger()
    
    private init() { }
    
//    var analyticsComponent: AnalyticsComponentProtocol { AnalyticsComponent.Performance }
//    @Inject private var reportsMediaUploader: IReportsMediaUploader
    
    public func reportMemory() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsed = ByteCountFormatter.string(fromByteCount: Int64(taskInfo.resident_size), countStyle: ByteCountFormatter.CountStyle.file)
//            let activeUploadingsCount = reportsMediaUploader.getLoadableObjects().count
            
            var params: [String: Any] = [
//                "uploadings_count": activeUploadingsCount,
                "memory_used": Int64(taskInfo.resident_size / 1_000_000)
            ]
            
            if let topViewController = UIApplication.topViewController() {
                let topPresentedVc = topViewController.topPresentedViewController
                
                params["topmost_vc"] = String(describing: topPresentedVc)
            }
            
            #if !DEBUG
            Crashlytics.crashlytics().record(error: CommonError(text: "memory warning"), userInfo: params)
//            sendAnalytics(AnalyticsAction.Performance.mainThreadBlock, tags: params)
            #endif
            
            printToConsole("Memory used: \(memoryUsed)")
        } else {
            printToConsole("Error with task_info(): " +
                    (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
    
    //Registering for Thermal Change notifications
    public func registerForThermalNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(responseToHeat(_:)),
                                               name: ProcessInfo.thermalStateDidChangeNotification,
                                               object: nil)
    }
    
    @objc private func responseToHeat(_ notification: Notification) {
        
        let state = ProcessInfo.processInfo.thermalState
        
//        let activeUploadingsCount = reportsMediaUploader.getLoadableObjects().count
        var params: [String: Any] = [
//            "uploadings_count": activeUploadingsCount,
            "thermal_state": state
        ]
        
        if let topViewController = UIApplication.topViewController() {
            let topPresentedVc = topViewController.topPresentedViewController
            
            params["topmost_vc"] = String(describing: topPresentedVc)
        }
        
        #if !DEBUG
//        sendAnalytics(AnalyticsAction.Performance.thermalState, tags: params)
        
        switch state {
        case .nominal:
            // No action required as such
            printToConsole("Thermal state: \(state)")
        case .fair:
            // Starts getting heated up. Try reducing CPU expensive operations.
            printToConsole("Thermal state: \(state)")
        case .serious:
            // Time to reduce the CPU usage and make sure you are not burning more
            Crashlytics.crashlytics().record(error: CommonError(text: "Thermal state is serious"), userInfo: params)
            printToConsole("Thermal state: \(state)")
        case .critical:
            Crashlytics.crashlytics().record(error: CommonError(text: "Thermal state is critical"), userInfo: params)
            
            // Reduce every operations and make initiate device cool down.
            printToConsole("Thermal state: \(state)")
        }
        #endif
    }
}
