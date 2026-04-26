import Foundation
import SwiftUI
import Kingfisher

struct CachedImage: View {
    let path: String?

    var body: some View {
        switch imageSource {
        case .valid(let imageURL):
            KFImage(imageURL)
                .placeholder { placeholder(for: .empty) }
                .onFailureView { placeholder(for: .fetchFailed) }
                .requestModifier { request in
                    request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")
                    if let accessToken = KeychainManager.shared.read(key: .accessToken) {
                        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
                    }
                }
                .resizable()
                .scaledToFill()
        case .empty:
            placeholder(for: .empty)
        case .invalid:
            placeholder(for: .invalidURL)
        }
    }

    private var imageSource: ImageSource {
        Self.makeImageSource(from: path)
    }

    private func placeholder(for style: PlaceholderStyle) -> some View {
        ZStack {
            style.backgroundColor

            Image("Pick_Fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundStyle(style.foregroundColor)
        }
    }

    private static func makeImageSource(from path: String?) -> ImageSource {
        guard
            let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty
        else {
            return .empty
        }

        if let url = URL(string: path), url.scheme != nil, url.host != nil {
            return .valid(url)
        }

        let baseURL = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let apiPath = normalizedAPIPath(from: path)
        guard let url = URL(string: baseURL + apiPath) else {
            return .invalid
        }

        return .valid(url)
    }

    private static func normalizedAPIPath(from path: String) -> String {
        let path = path.hasPrefix("/") ? path : "/\(path)"
        return path.hasPrefix("/data/") ? "/v1\(path)" : path
    }
}

private enum ImageSource {
    case empty
    case invalid
    case valid(URL)
}

private enum PlaceholderStyle {
    case empty
    case invalidURL
    case fetchFailed

    var backgroundColor: Color {
        switch self {
        case .empty, .fetchFailed:
            YPColor.gray15
        case .invalidURL:
            Color(hex: "#FFF9E9")
        }
    }

    var foregroundColor: Color {
        switch self {
        case .empty, .invalidURL:
            YPColor.gray60
        case .fetchFailed:
            YPColor.actionAccent
        }
    }
}
