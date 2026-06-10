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
    var sensitivePayloadToken: UUID?
    var createdAt: Date

    init(
        destination: AppLaunchDestination,
        assignmentID: UUID? = nil,
        action: AppLaunchAction = .none,
        sensitivePayloadToken: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.destination = destination
        self.assignmentID = assignmentID
        self.action = action
        self.sensitivePayloadToken = sensitivePayloadToken
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
    static let storageKey = "GradeDraft.pendingAppLaunchRequest.v2"
    static let legacyStorageKey = "GradeDraft.pendingAppLaunchRequest.v1"

    @discardableResult
    static func save(_ request: AppLaunchRequest, defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? JSONEncoder().encode(request) else { return false }
        defaults.set(data, forKey: storageKey)
        defaults.removeObject(forKey: legacyStorageKey)
        return true
    }

    static func consume(defaults: UserDefaults = .standard) -> AppLaunchRequest? {
        let request: AppLaunchRequest?
        if let data = defaults.data(forKey: storageKey) {
            request = try? JSONDecoder().decode(AppLaunchRequest.self, from: data)
            defaults.removeObject(forKey: storageKey)
        } else if let data = defaults.data(forKey: legacyStorageKey) {
            request = try? JSONDecoder().decode(AppLaunchRequest.self, from: data)
            defaults.removeObject(forKey: legacyStorageKey)
        } else {
            request = nil
        }
        AppLaunchSensitivePayloadStore.purgeExpiredPayloads()
        return request
    }
}

enum AppLaunchSensitivePayloadError: LocalizedError, Equatable {
    case emptyText
    case payloadTooLarge(maximumBytes: Int)
    case unreadableTextEncoding

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Paste non-empty student work text before running this shortcut."
        case .payloadTooLarge(let maximumBytes):
            return "Pasted student work is too large for a Shortcut handoff. Keep the pasted text under \(maximumBytes) bytes, or import the work inside the app."
        case .unreadableTextEncoding:
            return "Pasted student work could not be encoded safely. Paste plain text or import the work inside the app."
        }
    }
}

enum AppLaunchSensitivePayloadStore {
    static let maxTextByteCount = 2 * 1024 * 1024
    static let payloadTimeToLive: TimeInterval = 24 * 60 * 60

    private static let appDirectoryName = "GradeDraft"
    private static let directoryName = "LaunchRequests"
    private static let fileExtension = "txt"

    static func saveText(
        _ text: String,
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        now: Date = Date()
    ) throws -> UUID {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppLaunchSensitivePayloadError.emptyText }
        guard let data = trimmed.data(using: .utf8) else { throw AppLaunchSensitivePayloadError.unreadableTextEncoding }
        guard data.count <= maxTextByteCount else {
            throw AppLaunchSensitivePayloadError.payloadTooLarge(maximumBytes: maxTextByteCount)
        }

        let directory = try payloadDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
        purgeExpiredPayloads(now: now, fileManager: fileManager, rootDirectory: rootDirectory)

        let token = UUID()
        let url = payloadURL(for: token, directory: directory)
        try data.write(to: url, options: protectedWriteOptions)
        LocalDataProtection.protectSensitiveFile(url, fileManager: fileManager)
        return token
    }

    static func consumeText(
        token: UUID,
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> String? {
        guard let directory = existingPayloadDirectory(fileManager: fileManager, rootDirectory: rootDirectory) else { return nil }
        let url = payloadURL(for: token, directory: directory)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        defer { try? fileManager.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url), data.count <= maxTextByteCount else { return nil }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return text.isEmpty ? nil : text
    }

    static func deletePayload(
        token: UUID,
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        guard let directory = existingPayloadDirectory(fileManager: fileManager, rootDirectory: rootDirectory) else { return }
        try? fileManager.removeItem(at: payloadURL(for: token, directory: directory))
    }

    static func purgeExpiredPayloads(
        olderThan maxAge: TimeInterval = payloadTimeToLive,
        now: Date = Date(),
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        guard let directory = existingPayloadDirectory(fileManager: fileManager, rootDirectory: rootDirectory) else { return }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where url.pathExtension == fileExtension {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile != false else { continue }
            let modifiedAt = values?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modifiedAt) > maxAge {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    static func payloadDirectory(fileManager: FileManager = .default, rootDirectory: URL? = nil) throws -> URL {
        let root = resolvedRootDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
        try LocalDataProtection.prepareSensitiveDirectory(root, fileManager: fileManager)
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try LocalDataProtection.prepareSensitiveDirectory(directory, fileManager: fileManager)
        return directory
    }

    private static func existingPayloadDirectory(fileManager: FileManager, rootDirectory: URL?) -> URL? {
        let directory = resolvedRootDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent(directoryName, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return directory
    }

    private static func resolvedRootDirectory(fileManager: FileManager, rootDirectory: URL?) -> URL {
        if let rootDirectory {
            return rootDirectory
        }
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return supportURL.appendingPathComponent(appDirectoryName, isDirectory: true)
    }

    private static func payloadURL(for token: UUID, directory: URL) -> URL {
        directory.appendingPathComponent(token.uuidString).appendingPathExtension(fileExtension)
    }

    private static var protectedWriteOptions: Data.WritingOptions {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUnlessOpen]
        #else
        return [.atomic]
        #endif
    }
}
