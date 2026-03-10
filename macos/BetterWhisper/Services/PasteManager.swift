import AppKit
import Carbon
import Foundation

final class PasteManager {
    /// Paste text into the active application.
    ///
    /// This saves the current clipboard contents, sets the new text,
    /// simulates Cmd+V, then restores the original clipboard after a short delay.
    func paste(text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let previousContents = savePasteboardContents(pasteboard)

        // Set the new text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulateCmdV()

            // Restore previous clipboard contents after paste has time to complete,
            // but only if nothing else has modified the clipboard since we pasted
            let changeCount = pasteboard.changeCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard pasteboard.changeCount == changeCount else { return }
                self.restorePasteboardContents(previousContents, to: pasteboard)
            }
        }
    }

    /// Copy text to the clipboard without pasting.
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Private

    /// Simulate pressing Cmd+V using CGEvent.
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for "V" is 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard Save/Restore

    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savePasteboardContents(_ pasteboard: NSPasteboard) -> [[PasteboardItem]] {
        var savedItems: [[PasteboardItem]] = []

        guard let items = pasteboard.pasteboardItems else { return savedItems }

        for item in items {
            var itemData: [PasteboardItem] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append(PasteboardItem(type: type, data: data))
                }
            }
            savedItems.append(itemData)
        }

        return savedItems
    }

    private func restorePasteboardContents(_ contents: [[PasteboardItem]], to pasteboard: NSPasteboard) {
        guard !contents.isEmpty else { return }

        pasteboard.clearContents()

        var pasteboardItems: [NSPasteboardItem] = []
        for itemGroup in contents {
            let item = NSPasteboardItem()
            for saved in itemGroup {
                item.setData(saved.data, forType: saved.type)
            }
            pasteboardItems.append(item)
        }

        pasteboard.writeObjects(pasteboardItems)
    }
}
