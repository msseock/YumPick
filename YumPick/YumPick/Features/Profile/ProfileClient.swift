import Foundation

// MARK: - Models

struct MyProfile: Equatable {
    let userID: String
    let email: String
    let nick: String
    let profileImage: String?
    let phoneNum: String?
}

// MARK: - Protocol

protocol ProfileClientProtocol {
    func fetchMyProfile() async throws -> MyProfile
    func updateMyProfile(nick: String?, phoneNum: String?, profileImage: String?) async throws -> MyProfile
    func uploadProfileImage(data: Data, fileName: String, mimeType: String) async throws -> String?
    func logout() async throws
}

// MARK: - Endpoints

private enum ProfileEndpoint: Endpoint {
    case myProfile
    case updateMyProfile(UpdateProfileRequest)
    case uploadProfileImage(MultipartData)

    var path: String {
        switch self {
        case .myProfile, .updateMyProfile:
            return "/v1/users/me/profile"
        case .uploadProfileImage:
            return "/v1/users/profile/image"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .myProfile:
            return .get
        case .updateMyProfile:
            return .put
        case .uploadProfileImage:
            return .post
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .myProfile:
            return .none
        case .updateMyProfile(let body):
            return .body(body)
        case .uploadProfileImage(let part):
            return .multipart([part])
        }
    }
}

// MARK: - DTOs

private struct MyProfileResponse: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let profileImage: String?
    let phoneNum: String?

    var domain: MyProfile {
        MyProfile(
            userID: user_id,
            email: email,
            nick: nick,
            profileImage: profileImage,
            phoneNum: phoneNum
        )
    }
}

private struct UpdateProfileRequest: Encodable {
    let nick: String?
    let phoneNum: String?
    let profileImage: String?
}

private struct ProfileImageUploadResponse: Decodable {
    let profileImage: String?
}

// MARK: - Real Implementation

final class ProfileClient: ProfileClientProtocol {
    private let loginClient: LoginClientProtocol

    init(loginClient: LoginClientProtocol = LoginClient()) {
        self.loginClient = loginClient
    }

    func fetchMyProfile() async throws -> MyProfile {
        let response: MyProfileResponse = try await NetworkManager.shared.request(
            ProfileEndpoint.myProfile
        )
        return response.domain
    }

    func updateMyProfile(nick: String?, phoneNum: String?, profileImage: String?) async throws -> MyProfile {
        let response: MyProfileResponse = try await NetworkManager.shared.request(
            ProfileEndpoint.updateMyProfile(
                UpdateProfileRequest(nick: nick, phoneNum: phoneNum, profileImage: profileImage)
            )
        )
        return response.domain
    }

    func uploadProfileImage(data: Data, fileName: String, mimeType: String) async throws -> String? {
        let response: ProfileImageUploadResponse = try await NetworkManager.shared.request(
            ProfileEndpoint.uploadProfileImage(
                MultipartData(
                    name: "profile",
                    fileName: fileName,
                    mimeType: mimeType,
                    data: data
                )
            )
        )
        return response.profileImage
    }

    func logout() async throws {
        try await loginClient.logout()
    }
}

// MARK: - Mock

final class MockProfileClient: ProfileClientProtocol {
    var fetchMyProfileResult: Result<MyProfile, Error> = .success(
        MyProfile(
            userID: "mock-id",
            email: "tester@yumpick.app",
            nick: "테스터",
            profileImage: nil,
            phoneNum: "01012345678"
        )
    )
    var updateMyProfileResult: Result<MyProfile, Error> = .success(
        MyProfile(
            userID: "mock-id",
            email: "tester@yumpick.app",
            nick: "수정된테스터",
            profileImage: nil,
            phoneNum: "01012345678"
        )
    )
    var uploadProfileImageResult: Result<String?, Error> = .success("/data/profiles/mock.jpg")
    var logoutResult: Result<Void, Error> = .success(())

    func fetchMyProfile() async throws -> MyProfile {
        try fetchMyProfileResult.get()
    }

    func updateMyProfile(nick: String?, phoneNum: String?, profileImage: String?) async throws -> MyProfile {
        try updateMyProfileResult.get()
    }

    func uploadProfileImage(data: Data, fileName: String, mimeType: String) async throws -> String? {
        try uploadProfileImageResult.get()
    }

    func logout() async throws {
        try logoutResult.get()
    }
}
