import SwiftUI
import WebKit

struct HomeBannerWebViewScreen: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var completionCount: Int?
    @State private var isShowingCompletionAlert = false
    @State private var isShowingTokenAlert = false

    var body: some View {
        NavigationStack {
            HomeBannerWebView(
                url: url,
                onAttendanceCompleted: { count in
                    completionCount = count
                    isShowingCompletionAlert = true
                },
                onAccessTokenUnavailable: {
                    isShowingTokenAlert = true
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("출석 완료", isPresented: $isShowingCompletionAlert) {
                Button("확인") {}
            } message: {
                if let completionCount {
                    Text("\(completionCount)번째 출석이 완료되었습니다.")
                } else {
                    Text("출석이 완료되었습니다.")
                }
            }
            .alert("로그인이 필요합니다", isPresented: $isShowingTokenAlert) {
                Button("확인") {}
            } message: {
                Text("다시 로그인한 뒤 이용해주세요.")
            }
        }
    }
}

struct HomeBannerWebView: UIViewRepresentable {
    let url: URL
    var accessTokenProvider: () -> String? = {
        KeychainManager.shared.read(key: .accessToken)
    }
    let onAttendanceCompleted: (Int?) -> Void
    let onAccessTokenUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            accessTokenProvider: accessTokenProvider,
            onAttendanceCompleted: onAttendanceCompleted,
            onAccessTokenUnavailable: onAccessTokenUnavailable
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: MessageName.clickAttendanceButton)
        controller.add(context.coordinator, name: MessageName.completeAttendance)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView

        var request = URLRequest(url: url)
        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: MessageName.clickAttendanceButton
        )
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: MessageName.completeAttendance
        )
    }
}

extension HomeBannerWebView {
    enum MessageName {
        static let clickAttendanceButton = "click_attendance_button"
        static let completeAttendance = "complete_attendance"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        private let accessTokenProvider: () -> String?
        private let onAttendanceCompleted: (Int?) -> Void
        private let onAccessTokenUnavailable: () -> Void

        init(
            accessTokenProvider: @escaping () -> String?,
            onAttendanceCompleted: @escaping (Int?) -> Void,
            onAccessTokenUnavailable: @escaping () -> Void
        ) {
            self.accessTokenProvider = accessTokenProvider
            self.onAttendanceCompleted = onAttendanceCompleted
            self.onAccessTokenUnavailable = onAccessTokenUnavailable
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case MessageName.clickAttendanceButton:
                sendAccessTokenToWeb()
            case MessageName.completeAttendance:
                let count = attendanceCount(from: message.body)
                onAttendanceCompleted(count)
            default:
                break
            }
        }

        private func sendAccessTokenToWeb() {
            guard let accessToken = accessTokenProvider() else {
                onAccessTokenUnavailable()
                return
            }

            guard
                let tokenData = try? JSONEncoder().encode(accessToken),
                let tokenLiteral = String(data: tokenData, encoding: .utf8)
            else {
                onAccessTokenUnavailable()
                return
            }

            webView?.evaluateJavaScript("requestAttendance(\(tokenLiteral))")
        }

        private func attendanceCount(from body: Any) -> Int? {
            if let count = body as? Int {
                return count
            }
            if let count = body as? Double {
                return Int(count)
            }
            if let count = body as? String {
                return Int(count)
            }
            return nil
        }
    }
}
