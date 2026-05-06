import SwiftUI
import UniformTypeIdentifiers

struct ChatDocumentPicker: UIViewControllerRepresentable {
    let onPick: (ChatAttachment) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (ChatAttachment) -> Void

        init(onPick: @escaping (ChatAttachment) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let stopAccessing = url.startAccessingSecurityScopedResource()
            defer { if stopAccessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else { return }
            onPick(ChatAttachment(
                kind: .pdf,
                data: data,
                fileName: url.lastPathComponent,
                mimeType: "application/pdf",
                thumbnail: nil
            ))
        }
    }
}
