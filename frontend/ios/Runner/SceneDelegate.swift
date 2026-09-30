import Flutter
import UIKit
import app_links

// v604 — Lien de LANCEMENT (app fermée) perdu depuis le passage aux scènes
// iOS (UIApplicationSceneManifest, Flutter 3.41). Le plugin app_links 6.4.1
// n'écoute que l'ancien cycle UIApplicationDelegate (launchOptions) ; avec
// les scènes, l'URL d'ouverture à froid arrive dans
// `scene(_:willConnectTo:options:)` et n'atteignait jamais Dart : l'app
// s'ouvrait sur l'Accueil (PAM, 30/09, simulateur). Les liens à chaud
// (`openURLContexts`, `continueUserActivity`) sont déjà relayés par Flutter
// aux plugins : on ne touche qu'au cas à froid pour ne rien livrer en double.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let ctx = connectionOptions.urlContexts.first {
      AppLinks.shared.handleLink(url: ctx.url)
    } else if let url = connectionOptions.userActivities
      .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
      AppLinks.shared.handleLink(url: url)
    }
  }
}
