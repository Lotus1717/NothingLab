import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    /// 进程级引擎，在 Scene 连接前启动，避免 120Hz 设备上 VSync 竞态。
    lazy var flutterEngine = FlutterEngine(name: "nonsense_prophet_engine")

    private var mlChannel: FlutterMethodChannel?
    private var engineStarted = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }

        startFlutterEngineIfNeeded()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// 在首个 Scene 创建 UI 之前启动引擎并注册插件（显式引擎路径，不用 FlutterImplicitEngineDelegate）。
    func startFlutterEngineIfNeeded() {
        guard !engineStarted else { return }
        engineStarted = true

        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)
        setupMLChannel(messenger: flutterEngine.binaryMessenger)
    }

    func setupMLChannel(messenger: FlutterBinaryMessenger) {
        mlChannel = FlutterMethodChannel(
            name: "com.nonsense_prophet/ml",
            binaryMessenger: messenger
        )

        mlChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {

            case "isLoaded":
                result(MLProphecyGenerator.shared.isModelLoaded)

            case "getLoadProgress":
                result(MLProphecyGenerator.shared.loadProgress)

            case "isDownloading":
                result(MLProphecyGenerator.shared.isDownloading)

            case "loadModel":
                Task {
                    do {
                        try await MLProphecyGenerator.shared.loadModel { progress in
                            DispatchQueue.main.async {
                                self.mlChannel?.invokeMethod("onLoadProgress", arguments: progress)
                            }
                        }
                        result(nil)
                    } catch {
                        result(FlutterError(
                            code: "MODEL_LOAD_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    }
                }

            case "generateProphecy":
                guard let args = call.arguments as? [String: Any],
                      let systemPrompt = args["system"] as? String,
                      let userPrompt = args["user"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "缺少 system/user 参数", details: nil))
                    return
                }
                Task {
                    do {
                        let prophecy = try await MLProphecyGenerator.shared.generateProphecy(
                            systemPrompt: systemPrompt,
                            userPrompt: userPrompt
                        )
                        result(prophecy)
                    } catch {
                        result(FlutterError(
                            code: "GENERATION_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    }
                }

            case "unloadModel":
                MLProphecyGenerator.shared.unloadModel()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
