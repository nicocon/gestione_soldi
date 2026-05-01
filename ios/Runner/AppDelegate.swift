import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    setupWatchConnectivity()
    setupFlutterWatchChannel()

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupWatchConnectivity() {
    guard WCSession.isSupported() else {
      print("WatchConnectivity non supportato su questo dispositivo")
      return
    }

    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  private func setupFlutterWatchChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("FlutterViewController non trovato")
      return
    }

    let watchChannel = FlutterMethodChannel(
      name: "pocketplan/watch",
      binaryMessenger: controller.binaryMessenger
    )

    watchChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }

      switch call.method {
      case "sendSummaryToWatch":
        guard let summary = call.arguments as? [String: Any] else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENTS",
              message: "Dati riepilogo non validi",
              details: nil
            )
          )
          return
        }

        self.sendSummaryToWatch(summary)
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func sendSummaryToWatch(_ summary: [String: Any]) {
    guard WCSession.isSupported() else {
      print("WatchConnectivity non supportato")
      return
    }

    let session = WCSession.default

    guard session.activationState == .activated else {
      print("WCSession non ancora attiva")
      return
    }

    do {
      try session.updateApplicationContext(summary)
      print("Riepilogo PocketPlan inviato al Watch:", summary)
    } catch {
      print("Errore invio dati al Watch:", error.localizedDescription)
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error = error {
      print("Errore attivazione WCSession iPhone:", error.localizedDescription)
    } else {
      print("WCSession iPhone attiva:", activationState.rawValue)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
