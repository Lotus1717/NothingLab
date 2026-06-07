import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      super.scene(scene, willConnectTo: session, options: connectionOptions)
      return
    }

    // 引擎已在 AppDelegate.didFinishLaunching 中启动；此处只绑定窗口与 VC。
    let flutterEngine = appDelegate.flutterEngine
    appDelegate.startFlutterEngineIfNeeded()
    registerSceneLifeCycle(with: flutterEngine)

    window = UIWindow(windowScene: windowScene)
    let controller = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
