import UIKit
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private var received = ""
  override func viewDidLoad() {
    super.viewDidLoad()
    title = NSLocalizedString("Add to Romlerk", comment: "")
    navigationItem.rightBarButtonItem?.title = NSLocalizedString("Add", comment: "")
    placeholder = NSLocalizedString("Review this text in Romlerk before saving a task.", comment: "")
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
    if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
      provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
        DispatchQueue.main.async { self?.setText(item as? String ?? "") }
      }
    } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
        DispatchQueue.main.async { self?.setText((item as? URL)?.absoluteString ?? "") }
      }
    }
  }
  private func setText(_ value: String) {
    received = value
    textView.text = value
    validateContent()
  }
  override func isContentValid() -> Bool {
    let text = contentText ?? received
    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= CaptureInbox.maxText
  }
  override func didSelectPost() {
    do {
      try CaptureInbox.append(contentText ?? received)
      extensionContext?.completeRequest(returningItems: nil)
    } catch {
      let alert = UIAlertController(title: NSLocalizedString("Could not add text", comment: ""), message: NSLocalizedString("Open Romlerk to review pending captures, then try again.", comment: ""), preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
      present(alert, animated: true)
    }
  }
  override func configurationItems() -> [Any]! { [] }
}
