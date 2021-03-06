//
//  ReactShareViewController.swift
//  RNShareMenu
//
//  DO NOT EDIT THIS FILE. IT WILL BE OVERRIDEN BY NPM OR YARN.
//
//  Created by Gustavo Parreira on 29/07/2020.
//

import RNShareMenu

class ReactShareViewController: ShareViewController, RCTBridgeDelegate, ReactShareViewDelegate {
  
  func sourceURL(for bridge: RCTBridge!) -> URL! {
#if DEBUG
    return RCTBundleURLProvider.sharedSettings()?
      .jsBundleURL(forBundleRoot: "index.share", fallbackResource: nil)
#else
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let bridge: RCTBridge! = RCTBridge(delegate: self, launchOptions: nil)
    let rootView = RCTRootView(
      bridge: bridge,
      moduleName: "ShareMenuModuleComponent",
      initialProperties: nil
    )
    self.view = rootView
    ShareMenuReactView.attachViewDelegate(self)
  }

  override func viewDidDisappear(_ animated: Bool) {
    cancel()
    ShareMenuReactView.detachViewDelegate()
  }

  func loadExtensionContext() -> NSExtensionContext {
    return extensionContext!
  }

  func openApp() {
    self.openHostApp()
  }

  func continueInApp(with item: NSExtensionItem, and extraData: [String:Any]?) {
    handlePost(item, extraData: extraData)
  }
}
