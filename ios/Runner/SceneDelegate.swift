import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if connectionOptions.shortcutItem?.type == "capture" { QuickCaptureBridge.enqueue() }
    for context in connectionOptions.urlContexts { _ = QuickCaptureBridge.open(context.url) }
  }
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let other = Set(URLContexts.filter { !QuickCaptureBridge.open($0.url) })
    if !other.isEmpty { super.scene(scene, openURLContexts: other) }
  }
  override func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    if shortcutItem.type == "capture" { QuickCaptureBridge.enqueue(); completionHandler(true) }
    else { completionHandler(false) }
  }
}
