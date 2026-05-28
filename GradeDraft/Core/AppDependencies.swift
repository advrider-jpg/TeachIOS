import Dependencies
import Foundation

struct ClockClient: Sendable {
    var now: @Sendable () -> Date
}

struct UUIDClient: Sendable {
    var random: @Sendable () -> UUID
}

struct FileClient: Sendable {
    var applicationSupportDirectory: @Sendable () throws -> URL
}

struct AppDependencies: Sendable {
    var clock: ClockClient
    var uuid: UUIDClient
    var fileClient: FileClient
}

private enum AppDependenciesKey: DependencyKey {
    static let liveValue = AppDependencies(
        clock: ClockClient(now: { Date() }),
        uuid: UUIDClient(random: { UUID() }),
        fileClient: FileClient(
            applicationSupportDirectory: {
                let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                guard let url else {
                    throw NSError(domain: "AppDependencies", code: 1)
                }
                return url
            }
        )
    )
}

extension DependencyValues {
    var app: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
