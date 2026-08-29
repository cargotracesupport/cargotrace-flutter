import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps key comes from Info.plist (GMapsAPIKey), which resolves the
    // gitignored ios/Flutter/Secrets.xcconfig. Guarded: with no key the app
    // still runs, the map view is simply blank.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMapsAPIKey") as? String,
       !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
