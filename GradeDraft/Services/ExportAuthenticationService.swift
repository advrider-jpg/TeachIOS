import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

protocol ExportAuthenticationServicing {
    func authenticateForSensitiveExport(reason: String) async -> ExportAuthenticationResult
}

struct ExportAuthenticationResult: Equatable {
    var allowed: Bool
    var authenticationPerformed: Bool
    var message: String?
}

struct LocalExportAuthenticationService: ExportAuthenticationServicing {
    func authenticateForSensitiveExport(reason: String) async -> ExportAuthenticationResult {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return ExportAuthenticationResult(
                allowed: true,
                authenticationPerformed: false,
                message: "Device authentication is unavailable; export continued after teacher confirmation."
            )
        }

        do {
            let allowed = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ExportAuthenticationResult(allowed: allowed, authenticationPerformed: true, message: nil)
        } catch {
            return ExportAuthenticationResult(
                allowed: false,
                authenticationPerformed: true,
                message: "Export canceled because device authentication was not completed."
            )
        }
        #else
        return ExportAuthenticationResult(
            allowed: true,
            authenticationPerformed: false,
            message: "Device authentication is unavailable on this platform."
        )
        #endif
    }
}
