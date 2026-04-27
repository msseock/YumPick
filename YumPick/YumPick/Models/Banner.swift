import Foundation

struct Banner: Codable, Identifiable, Hashable {
    let name: String
    let imageUrl: String
    let payload: Payload

    var id: String { name }

    struct Payload: Codable, Hashable {
        let type: String
        let value: String
    }
}
