import Foundation
import Observation
import RealmSwift

@Observable
final class ChatUserDirectory {
    static let shared = ChatUserDirectory()

    private var profiles: [String: ChatSender] = [:]

    @ObservationIgnored private let configuration: Realm.Configuration

    init(configuration: Realm.Configuration = RealmConfig.make()) {
        self.configuration = configuration
        hydrateFromRealm()
    }

    func profile(for userID: String) -> ChatSender? {
        profiles[userID]
    }

    func upsert(_ sender: ChatSender) {
        upsert([sender])
    }

    func upsert(_ senders: [ChatSender]) {
        guard !senders.isEmpty else { return }

        var changed = false
        for sender in senders {
            if profiles[sender.userID] != sender {
                profiles[sender.userID] = sender
                changed = true
            }
        }
        guard changed else { return }

        persist(senders)
    }

    private func hydrateFromRealm() {
        do {
            let realm = try Realm(configuration: configuration)
            let objects = realm.objects(ChatUserProfileObject.self)
            for object in objects {
                profiles[object.userID] = ChatSender(
                    userID: object.userID,
                    nick: object.nick,
                    profileImage: object.profileImage
                )
            }
        } catch {
            print("ChatUserDirectory hydrate failed: \(error)")
        }
    }

    private func persist(_ senders: [ChatSender]) {
        do {
            let realm = try Realm(configuration: configuration)
            try realm.write {
                let now = Date()
                for sender in senders {
                    let object = ChatUserProfileObject()
                    object.userID = sender.userID
                    object.nick = sender.nick
                    object.profileImage = sender.profileImage
                    object.updatedAt = now
                    realm.add(object, update: .modified)
                }
            }
        } catch {
            print("ChatUserDirectory persist failed: \(error)")
        }
    }
}
