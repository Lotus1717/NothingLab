import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      super.scene(scene, willConnectTo: session, options: connectionOptions)
      return
    }

    // 程序化创建 FlutterViewController，确保 sharedSetup（含 createShell）
    // 在 viewDidLoad 之前完成。Storyboard 加载时可能先触发 viewDidLoad，
    // 在 120Hz 设备上会因 platformTaskRunner 为空而在 VSyncClient 处崩溃。
    window = UIWindow(windowScene: windowScene)
    let controller = FlutterViewController(project: nil, nibName: nil, bundle: nil)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
