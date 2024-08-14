import Cocoa
import FlutterMacOS

public class DuckDBPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "duckdb", binaryMessenger: registrar.messenger)
    let instance = DuckDBPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "initPlugin":
      result("ok")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

