// Retains security-scoped folder bookmarks and native file export for the lifetime of the window.

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var folderChannel: FlutterMethodChannel?
  private var accessedFolders: [String: URL] = [:]

  private func folderAccess(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Resolve bookmarks back to the exact selected folder before acquiring scope;
    // a stale bookmark must never silently redirect imports to another location.
    guard let path = call.arguments as? String else {
      result(FlutterError(code: "invalid_path", message: "Missing folder path", details: nil))
      return
    }
    let key = "omniquiz.folder." + path
    do {
      if call.method == "remember" {
        let url = URL(fileURLWithPath: path)
        let bookmark = try url.bookmarkData(options: .withSecurityScope,
          includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: key)
      } else if call.method != "restore" {
        result(FlutterMethodNotImplemented)
        return
      }
      if accessedFolders[path] == nil,
          let bookmark = UserDefaults.standard.data(forKey: key) {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
          relativeTo: nil, bookmarkDataIsStale: &stale)
        guard url.standardizedFileURL.path == URL(fileURLWithPath: path).standardizedFileURL.path,
              url.startAccessingSecurityScopedResource() else {
          result(FlutterError(code: "folder_access", message: "Select the library folder again", details: nil))
          return
        }
        accessedFolders[path] = url
        if stale {
          let renewed = try url.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
          UserDefaults.standard.set(renewed, forKey: key)
        }
      }
      result(nil)
    } catch {
      result(FlutterError(code: "folder_access", message: "Could not retain folder access", details: nil))
    }
  }

  deinit {
    // Each successful startAccessing call is balanced once at window teardown.
    for url in accessedFolders.values { url.stopAccessingSecurityScopedResource() }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    folderChannel = FlutterMethodChannel(name: "omniquiz/folders",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    folderChannel?.setMethodCallHandler { [weak self] call, result in
      self?.folderAccess(call, result: result)
    }

    super.awakeFromNib()
  }
}
