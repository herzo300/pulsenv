import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 13.0, *) {
      WorkmanagerPlugin.registerPeriodicTask(
        withIdentifier: "com.soobshio.reports.background.refresh",
        frequency: NSNumber(value: 15 * 60)
      )
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
