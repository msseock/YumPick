import Foundation
import UIKit

@MainActor
final class ChatPushHandler {
    static let shared = ChatPushHandler()
    private init() {}

    private weak var appRouter: AppRouter?
    var currentOpenRoomID: String?
    weak var listViewModel: ChatRoomListViewModel?

    func configure(router: AppRouter) {
        appRouter = router
    }

    // MARK: - 푸시 수신 (포그라운드 수신 / 사용자 탭)

    func handle(userInfo: [AnyHashable: Any], isUserTap: Bool) {
        guard let roomID = userInfo["room_id"] as? String else { return }
        saveMessageIfPresent(from: userInfo)
        if let vm = listViewModel {
            Task { await vm.fetchRooms() }
        }
        if isUserTap {
            navigate(to: roomID)
        }
    }

    // MARK: - 딥링크 네비게이션

    private func navigate(to roomID: String) {
        guard let router = appRouter else { return }
        router.selectedTab = .profile
        router.profilePath = [.chatRooms, .chatRoom(roomID)]
    }

    // MARK: - 페이로드 → Realm 저장

    private func saveMessageIfPresent(from userInfo: [AnyHashable: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo)
            let message = try JSONDecoder().decode(ChatMessage.self, from: data)
            let repo = ChatRealmRepository()
            try repo.saveAll([message], isRoomOpen: false)
        } catch {
            // 파싱 실패 무시 — 채팅방 진입 시 sync로 보정
        }
    }
}
