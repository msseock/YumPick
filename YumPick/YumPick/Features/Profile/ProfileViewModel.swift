import Foundation
import UIKit

enum ProfileImageError: LocalizedError {
    case invalidImage
    case oversized

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 불러올 수 없습니다."
        case .oversized:
            return "프로필 이미지는 1MB 이하의 jpg 또는 png만 사용할 수 있습니다."
        }
    }
}

@Observable
@MainActor
final class ProfileViewModel {
    var isLoading = false
    var isSaving = false
    var isUploadingImage = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var didLogout = false
    var profile: MyProfile?
    var nick = ""
    var phoneNum = ""
    var localProfileImageData: Data?

    private let client: ProfileClientProtocol
    private let maxProfileImageBytes = 1 * 1024 * 1024

    init(client: ProfileClientProtocol = ProfileClient()) {
        self.client = client
    }

    var hasChanges: Bool {
        guard let profile else { return false }
        return nick.trimmingCharacters(in: .whitespacesAndNewlines) != profile.nick
            || normalizedPhoneNum != (profile.phoneNum ?? "")
    }

    var canSave: Bool {
        !isSaving && !isLoading && !isUploadingImage && !nick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasChanges
    }

    func fetchProfile() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            apply(try await client.fetchMyProfile())
        } catch {
            errorMessage = "프로필을 불러오지 못했습니다."
        }
    }

    func saveProfile() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await client.updateMyProfile(
                nick: trimmedNick,
                phoneNum: normalizedPhoneNum.isEmpty ? nil : normalizedPhoneNum,
                profileImage: profile?.profileImage
            )
            apply(updated)
            successMessage = "프로필이 수정되었습니다."
        } catch {
            errorMessage = "프로필 수정에 실패했습니다."
        }
    }

    func uploadProfileImage(_ data: Data) async {
        isUploadingImage = true
        errorMessage = nil
        successMessage = nil
        defer { isUploadingImage = false }

        do {
            let jpegData = try preparedProfileJPEGData(from: data)
            let path = try await client.uploadProfileImage(
                data: jpegData,
                fileName: "profile_\(UUID().uuidString).jpg",
                mimeType: "image/jpeg"
            )
            let updated = try await client.updateMyProfile(
                nick: nil,
                phoneNum: nil,
                profileImage: path
            )
            apply(updated)
            localProfileImageData = jpegData
            successMessage = "프로필 이미지가 변경되었습니다."
        } catch let error as ProfileImageError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "프로필 이미지 업로드에 실패했습니다."
        }
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.logout()
            didLogout = true
        } catch {
            errorMessage = error.localizedDescription
            didLogout = true
        }
    }

    private var trimmedNick: String {
        nick.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPhoneNum: String {
        phoneNum.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply(_ profile: MyProfile) {
        self.profile = profile
        nick = profile.nick
        phoneNum = profile.phoneNum ?? ""
        localProfileImageData = nil
        UserSession.shared.set(
            userID: profile.userID,
            nick: profile.nick,
            profileImage: profile.profileImage
        )
    }

    private func preparedProfileJPEGData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw ProfileImageError.invalidImage
        }

        var quality: CGFloat = 0.85
        while quality >= 0.2 {
            if let jpegData = image.jpegData(compressionQuality: quality),
               jpegData.count <= maxProfileImageBytes {
                return jpegData
            }
            quality -= 0.15
        }

        throw ProfileImageError.oversized
    }
}
