import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextTaskId = 1

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.rahel.app/background_task", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "startBackgroundTask" {
        let taskId = self.startBackgroundTask()
        result(taskId)
      } else if call.method == "endBackgroundTask" {
        if let args = call.arguments as? [String: Any],
           let taskId = args["taskId"] as? Int {
          self.endBackgroundTask(taskId: taskId)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing taskId argument", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startBackgroundTask() -> Int {
    let taskId = nextTaskId
    nextTaskId += 1

    var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "RahelBgTask_\(taskId)") { [weak self] in
      self?.endBackgroundTask(taskId: taskId)
    }

    if bgTaskId != .invalid {
      backgroundTasks[taskId] = bgTaskId
      return taskId
    }
    return -1
  }

  private func endBackgroundTask(taskId: Int) {
    if let bgTaskId = backgroundTasks[taskId], bgTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(bgTaskId)
      backgroundTasks.removeValue(forKey: taskId)
    }
  }
}

