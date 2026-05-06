import PDFKit
import SwiftUI

struct PDFViewerView: View {
    let path: String
    let onDismiss: () -> Void

    @State private var document: PDFDocument? = nil
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(YPColor.textTertiary)
                    Text("PDF를 불러올 수 없습니다")
                        .ypFont(YPFont.body2)
                        .foregroundStyle(YPColor.textSecondary)
                }
            } else if let document {
                PDFKitView(document: document)
                    .ignoresSafeArea(edges: .bottom)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .task { await loadDocument() }
    }

    private func loadDocument() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = resolvedURL(from: path) else {
            loadFailed = true
            return
        }

        var request = URLRequest(url: url)
        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")
        if let token = KeychainManager.shared.read(key: .accessToken) {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let doc = PDFDocument(data: data) {
                document = doc
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }

    private func resolvedURL(from path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil, url.host != nil {
            return url
        }
        let base = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        let apiPath = normalized.hasPrefix("/data/") ? "/v1\(normalized)" : normalized
        return URL(string: base + apiPath)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.backgroundColor = .black
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
