import Foundation

enum AppLaunchDestination: String, Codable, Equatable, Sendable {
    case home
    case assignments
    case review
    case exports
    case aiReadiness
    case finalReview
    case latestDraft
    case packetPreview
    case ocrReview
    case curriculum
    case studentWork
}

enum AppLaunchAction: String, Codable, Equatable, Sendable {
    case none
    case preparePacketPreview
    case createAssignmentShell
    case startManualFinalReview
    case applyRecommendedAIConstraints
    case applyPastedStudentText
}

struct AppLaunchRequest: Codable, Equatable, Sendable {
    var destination: AppLaunchDestination
    var assignmentID: UUID?
    var action: AppLaunchAction
    var payloadText: String?
    var createdAt: Date

    init(
        destination: AppLaunchDestination,
        assignmentID: UUID? = nil,
        action: AppLaunchAction = .none,
        payloadText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.destination = destination
        self.assignmentID = assignmentID
        self.action = action
        self.payloadText = payloadText
        self.createdAt = Date(timeIntervalSinceReferenceDate: floor(createdAt.timeIntervalSinceReferenceDate * 1000) / 1000)
    }
}

enum AppLaunchRoute: Hashable, Identifiable {
    case assignmentOverview(UUID)
    case aiReadiness(UUID)
    case finalReview(UUID)
    case packetPreview(UUID)
    case ocrReview(UUID)
    case curriculum(UUID)
    case studentWork(UUID)
    case exports(UUID?)

    var id: String {
        switch self {
        case .assignmentOverview(let id):
            return "assignment-\(id.uuidString)"
        case .aiReadiness(let id):
            return "ai-readiness-\(id.uuidString)"
        case .finalReview(let id):
            return "final-\(id.uuidString)"
        case .packetPreview(let id):
            return "packet-\(id.uuidString)"
        case .ocrReview(let id):
            return "ocr-\(id.uuidString)"
        case .curriculum(let id):
            return "curriculum-\(id.uuidString)"
        case .studentWork(let id):
            return "student-work-\(id.uuidString)"
        case .exports(let id):
            return "exports-\(id?.uuidString ?? "current")"
        }
    }
}

enum AppLaunchRequestStore {
    static let storageKey = "GradeDraft.pendingAppLaunchRequest.v1"

    static func save(_ request: AppLaunchRequest, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func consume(defaults: UserDefaults = .standard) -> AppLaunchRequest? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        defaults.removeObject(forKey: storageKey)
        return try? JSONDecoder().decode(AppLaunchRequest.self, from: data)
    }
}
