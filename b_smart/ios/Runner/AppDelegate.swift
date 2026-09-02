import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeAdFactory: BSmartNativeAdFactory?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let factory = BSmartNativeAdFactory()
    nativeAdFactory = factory
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "bsmart_native_ad_factory",
      nativeAdFactory: factory
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}