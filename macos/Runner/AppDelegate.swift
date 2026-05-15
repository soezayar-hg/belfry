import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  weak var downstreamNotificationDelegate: UNUserNotificationCenterDelegate?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    let center = UNUserNotificationCenter.current()
    downstreamNotificationDelegate = center.delegate
    center.delegate = self
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    downstreamNotificationDelegate?.userNotificationCenter?(
      center,
      willPresent: notification,
      withCompletionHandler: { _ in }
    )

    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list, .sound])
      return
    }

    completionHandler([.alert, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows {
      window.makeKeyAndOrderFront(nil)
    }

    if let downstream = downstreamNotificationDelegate,
       downstream.responds(to: #selector(userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      downstream.userNotificationCenter?(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
      return
    }

    completionHandler()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
