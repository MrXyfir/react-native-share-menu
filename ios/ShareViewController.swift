import MobileCoreServices
import UIKit
import Social
import RNShareMenu

extension Collection where Iterator.Element == [String:String] {
  func toJSONString(options: JSONSerialization.WritingOptions = .prettyPrinted) -> String {
    if let arr = self as? [[String:String]],
       let dat = try? JSONSerialization.data(withJSONObject: arr, options: options),
       let str = String(data: dat, encoding: String.Encoding.utf8) {
      return str
    }
    return "[]"
  }
}
class ShareViewController: SLComposeServiceViewController {
  var hostAppId: String?
  var hostAppUrlScheme: String?
  var shareDataStr:String?
  var items:[[String:String]]?
  var itemCount:Int = 0
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let hostAppId = Bundle.main.object(forInfoDictionaryKey: HOST_APP_IDENTIFIER_INFO_PLIST_KEY) as? String {
      self.hostAppId = hostAppId
    } else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
    }
    
    if let hostAppUrlScheme = Bundle.main.object(forInfoDictionaryKey: HOST_URL_SCHEME_INFO_PLIST_KEY) as? String {
      self.hostAppUrlScheme = hostAppUrlScheme
    } else {
      print("Error: \(NO_INFO_PLIST_URL_SCHEME_ERROR)")
    }
  }
  
  override func isContentValid() -> Bool {
    // Do validation of contentText and/or NSExtensionContext attachments here
    return true
  }
  
  override func configurationItems() -> [Any]! {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
      cancelRequest()
      return []
    }
    handlePost(item)
    return []
  }
  
  func handlePost(_ item: NSExtensionItem, extraData: [String:Any]? = nil) {
    guard (item.attachments?.first) != nil else {
      cancelRequest()
      return
    }
    self.items = [[String: String]]()
    self.itemCount = item.attachments?.count ?? 0
    if let data = extraData {
      storeExtraData(data)
    } else {
      removeExtraData()
    }
    let attachments:[NSItemProvider]! = item.attachments
    for provider in attachments {
      if provider.isText && provider.hasItemConformingToTypeIdentifier(kUTTypeText as String){
        storeText(withProvider: provider)
      } else if provider.isURL {
        storeUrl(withProvider: provider)
      } else {
        if provider.hasItemConformingToTypeIdentifier("public.image") {
          self.storeImage(withProvider: provider)
        } else if provider.hasItemConformingToTypeIdentifier("public.movie") {
          self.storeVideo(withProvider: provider)
        } else {
          storeFile(withProvider: provider)
        }
      }
    }
  }
  
  func storeExtraData(_ data: [String:Any]) {
    guard let hostAppId = self.hostAppId else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
      print("Error: \(NO_APP_GROUP_ERROR)")
      return
    }
    userDefaults.set(data, forKey: USER_DEFAULTS_EXTRA_DATA_KEY)
    userDefaults.synchronize()
  }
  
  func removeExtraData() {
    guard let hostAppId = self.hostAppId else {
      print("Error: \(NO_INFO_PLIST_INDENTIFIER_ERROR)")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
      print("Error: \(NO_APP_GROUP_ERROR)")
      return
    }
    userDefaults.removeObject(forKey: USER_DEFAULTS_EXTRA_DATA_KEY)
    userDefaults.synchronize()
  }
  
  func storeText(withProvider provider: NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (data, error) in
      self.itemCount = self.itemCount - 1
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      if let text = data as? String {
        self.items!.append([DATA_KEY: text, MIME_TYPE_KEY: "text/plain"])
      } else if let text2 = data as? NSAttributedString {
        self.items!.append([DATA_KEY: text2.string, MIME_TYPE_KEY: "text/plain"])
      } else {
        self.exit(withError: error.debugDescription)
        return
      }
      self.openAppIfDone()
    }
  }
  func storeImage(withProvider provider:NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (data, error) in
      self.itemCount = self.itemCount - 1
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      if let url = data as? URL {
        if !url.isFileURL {
          self.items!.append([DATA_KEY: url.absoluteString, MIME_TYPE_KEY: url.extractMimeType()])
          self.openAppIfDone()
        } else {
          self.saveAndOpen(url:url)
        }
        return
      }
      guard let image = data as? UIImage else {
        self.exit(withError: COULD_NOT_FIND_URL_ERROR)
        return
      }
      guard let hostAppId = self.hostAppId else {
        self.exit(withError: NO_INFO_PLIST_INDENTIFIER_ERROR)
        return
      }
      guard let groupFileManagerContainer = FileManager.default
              .containerURL(forSecurityApplicationGroupIdentifier: "group.\(hostAppId)") else {
        self.openAppIfDone()
        return
      }
      let imageData = image.pngData()
      let fileExtension = "png"
      let fileName = UUID().uuidString
      let filePath = groupFileManagerContainer
        .appendingPathComponent("\(fileName).\(fileExtension)")
      do {
        try imageData?.write(to: filePath)
      }
      catch (let error) {
        print("Could not save image to \(filePath): \(error)")
        self.openAppIfDone()
        return
      }
      self.items!.append([DATA_KEY: filePath.absoluteString, MIME_TYPE_KEY: "image/png"])
      self.openAppIfDone()
    }
  }
  func storeVideo(withProvider provider:NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { (data, error) in
      self.itemCount = self.itemCount - 1
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      if let url = data as? URL {
        if url.isFileURL {
          self.saveAndOpen(url:url)
        } else {
          self.items!.append([DATA_KEY: url.absoluteString, MIME_TYPE_KEY: url.extractMimeType()])
          self.openAppIfDone()
        }
      }
    }
  }
  func storeUrl(withProvider provider: NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (data, error) in
      self.itemCount = self.itemCount - 1
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      guard let url = data as? URL else {
        self.exit(withError: COULD_NOT_FIND_URL_ERROR)
        return
      }
      if url.isFileURL {
        self.saveAndOpen(url:url)
      } else {
        self.items!.append([DATA_KEY: url.absoluteString, MIME_TYPE_KEY: url.extractMimeType()])
        self.openAppIfDone()
      }
    }
  }
  func saveAndOpen(url:URL) {
    guard let hostAppId = self.hostAppId else {
      self.exit(withError: NO_INFO_PLIST_INDENTIFIER_ERROR)
      return
    }
    guard let groupFileManagerContainer = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.\(hostAppId)")
    else {
      self.exit(withError: NO_APP_GROUP_ERROR)
      return
    }
    if let tmp  = NSData(contentsOf: url) {
      let fileName = url.pathComponents.last ?? UUID().uuidString
      let filePath = groupFileManagerContainer
        .appendingPathComponent("\(fileName)")
      do {
        try tmp.write(to: filePath)
        self.items!.append([DATA_KEY: filePath.absoluteString, MIME_TYPE_KEY: url.extractMimeType()])
        self.openAppIfDone()
      }
      catch (let error) {
        print("Could not save image to \(filePath): \(error)")
        self.openAppIfDone()
        return
      }
    } else {
      self.items!.append([DATA_KEY: url.absoluteString, MIME_TYPE_KEY: url.extractMimeType()])
      self.openAppIfDone()
      return
    }
  }
  
  func storeFile(withProvider provider: NSItemProvider) {
    provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { (data, error) in
      self.itemCount = self.itemCount - 1
      guard (error == nil) else {
        self.exit(withError: error.debugDescription)
        return
      }
      guard let url = data as? URL else {
        self.exit(withError: COULD_NOT_FIND_IMG_ERROR)
        return
      }
      guard let hostAppId = self.hostAppId else {
        self.exit(withError: NO_INFO_PLIST_INDENTIFIER_ERROR)
        return
      }
      guard let groupFileManagerContainer = FileManager.default
              .containerURL(forSecurityApplicationGroupIdentifier: "group.\(hostAppId)")
      else {
        self.exit(withError: NO_APP_GROUP_ERROR)
        return
      }
      
      let mimeType = url.extractMimeType()
      let fileExtension = url.pathExtension
      let fileName = UUID().uuidString
      let filePath = groupFileManagerContainer
        .appendingPathComponent("\(fileName).\(fileExtension)")
      
      guard self.moveFileToDisk(from: url, to: filePath) else {
        self.exit(withError: COULD_NOT_SAVE_FILE_ERROR)
        return
      }
      self.items!.append([DATA_KEY: filePath.absoluteString, MIME_TYPE_KEY: mimeType])
      self.openAppIfDone()
    }
  }
  
  func moveFileToDisk(from srcUrl: URL, to destUrl: URL) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: destUrl.path) {
        try FileManager.default.removeItem(at: destUrl)
      }
      try FileManager.default.copyItem(at: srcUrl, to: destUrl)
    } catch (let error) {
      print("Could not save file from \(srcUrl) to \(destUrl): \(error)")
      return false
    }
    
    return true
  }
  
  func exit(withError error: String) {
    print("Error: \(error)")
    cancelRequest()
  }
  func openAppIfDone() {
    if itemCount <= 0 {
      guard let hostAppId = self.hostAppId else {
        self.exit(withError: NO_INFO_PLIST_INDENTIFIER_ERROR)
        return
      }
      guard let userDefaults = UserDefaults(suiteName: "group.\(hostAppId)") else {
        self.exit(withError: NO_APP_GROUP_ERROR)
        return
      }
      userDefaults.set(items,
                       forKey: USER_DEFAULTS_KEY)
      userDefaults.synchronize()
      self.openHostApp()
    }
  }
  internal func openHostApp() {
    guard let urlScheme = self.hostAppUrlScheme else {
      exit(withError: NO_INFO_PLIST_URL_SCHEME_ERROR)
      return
    }
    let jsonString = items!.toJSONString().data(using: .utf8)!.base64EncodedString()
    let escapedString = "share?sharedData=\(jsonString)"
    let urlString = urlScheme + escapedString
    let url = URL(string: urlString)
    let selectorOpenURL = sel_registerName("openURL:")
    print("url =\(url!)")
    var responder: UIResponder? = self
    while responder != nil {
      if responder?.responds(to: selectorOpenURL) == true {
        responder?.perform(selectorOpenURL, with: url)
      }
      responder = responder!.next
    }
    
    completeRequest()
  }
  
  func completeRequest() {
    super.didSelectCancel()
  }
  
  func cancelRequest() {
    super.didSelectCancel()
  }
  
}
