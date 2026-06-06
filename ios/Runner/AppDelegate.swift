import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    private var mlChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        
        // 注册 MethodChannel 供 Dart 端调用
        let messenger = engineBridge.applicationRegistrar.messenger()
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
                            // 通过 EventChannel 发送进度（改为调用 method）
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
