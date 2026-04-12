import Flutter
import UIKit
import native_geofence

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // ⚠️ Must be called BEFORE GeneratedPluginRegistrant.register
    // native_geofence checks for this callback during plugin registration
    NativeGeofencePlugin.setPluginRegistrantCallback(registerPlugins)

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Registers plugins needed in background isolates (for geofence wake-ups)
private func registerPlugins(registry: FlutterPluginRegistry) {
  if !registry.hasPlugin("NativeGeofencePlugin") {
    NativeGeofencePlugin.register(
      with: registry.registrar(forPlugin: "NativeGeofencePlugin")!)
  }
}
