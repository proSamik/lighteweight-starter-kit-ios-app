import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var subscriptionStartedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case subscriptionStartedAt = "subscription_started_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
