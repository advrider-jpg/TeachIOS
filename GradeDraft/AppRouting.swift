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
    var payloadFileToken: String?
    var createdAt: Date

    init(
        destination: AppLaunchDestination,
        assignmentID: UUID? = nil,
        action: AppLaunchAction = .none,
        payloadText: String? = nil,
        payloadFileToken: String? = nil,
        createdAt: Date = Date()
    ) {
        self.destination = destination
        self.assignmentID = assignmentID
        self.action = action
        self.payloadText = payloadText
        self.payloadFileToken = payloadFileToken
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
    private static let payloadTTL: TimeInterval = 15 * 60

    @discardableResult
    static func save(_ request: AppLaunchRequest, defaults: UserDefaults = .standard) -> Bool {
        cleanupExpiredPayloadFiles(now: request.createdAt)
        var storedRequest = request
        if let payload = request.payloadText, !payload.isEmpty {
            do {
                let token = UUID().uuidString
                try writePayload(payload, token: token)
                storedRequest.payloadText = nil
                storedRequest.payloadFileToken = token
            } catch {
                return false
            }
        }
        guard let data = try? JSONEncoder().encode(storedRequest) else { return false }
        defaults.set(data, forKey: storageKey)
        return true
    }

    static func consume(defaults: UserDefaults = .standard) -> AppLaunchRequest? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        defaults.removeObject(forKey: storageKey)
        guard var request = try? JSONDecoder().decode(AppLaunchRequest.self, from: data) else { return nil }
        if let token = request.payloadFileToken {
            request.payloadText = try? readAndDeletePayload(token: token, createdAt: request.createdAt)
            request.payloadFileToken = nil
        }
        cleanupExpiredPayloadFiles(now: Date())
        return request
    }

    private static func payloadDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = base
            .appendingPathComponent("GradeDraft", isDirectory: true)
            .appendingPathComponent("ShortcutPayloads", isDirectory: true)
        try LocalDataProtection.prepareSensitiveDirectory(directory, fileManager: fileManager)
        return directory
    }

    private static func payloadURL(token: String, fileManager: FileManager = .default) throws -> URL {
        try payloadDirectory(fileManager: fileManager).appendingPathComponent("\(token).txt", isDirectory: false)
    }

    private static func writePayload(_ payload: String, token: String, fileManager: FileManager = .default) throws {
        let url = try payloadURL(token: token, fileManager: fileManager)
        try payload.write(to: url, atomically: true, encoding: .utf8)
        LocalDataProtection.protectSensitiveFile(url, fileManager: fileManager)
    }

    private static func readAndDeletePayload(token: String, createdAt: Date, fileManager: FileManager = .default) throws -> String? {
        let url = try payloadURL(token: token, fileManager: fileManager)
        defer { try? fileManager.removeItem(at: url) }
        guard Date().timeIntervalSince(createdAt) <= payloadTTL else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func cleanupExpiredPayloadFiles(now: Date, fileManager: FileManager = .default) {
        guard let directory = try? payloadDirectory(fileManager: fileManager),
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files {
            let createdAt = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if now.timeIntervalSince(createdAt) > payloadTTL {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
