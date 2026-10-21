import Flutter
import UIKit

/// Lets the system export an existing archive without a second in-memory copy.
final class BackupExporter: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var pending: FlutterResult?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "io.github.missdrop.omniquiz/backup", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(BackupExporter(registrar: registrar), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exportBackup" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "An export is already open.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String else {
      fail(result); return
    }
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath()
    let prefix = temporary.path.hasSuffix("/") ? temporary.path : temporary.path + "/"
    guard url.path.hasPrefix(prefix),
      url.lastPathComponent == "OmniQuiz-backup.zip",
      FileManager.default.fileExists(atPath: url.path),
      var presenter = registrar?.viewController else {
      fail(result); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: url, in: .exportToService)
    }
    picker.delegate = self
    pending = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]) {
    finish(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }

  private func finish(_ success: Bool?) {
    let result = pending
    pending = nil
    if success == false { if let result { fail(result) } }
    else { result?(success) }
  }

  private func fail(_ result: FlutterResult) {
    result(FlutterError(code: "export_failed", message: "Could not save the backup.", details: nil))
  }
}
