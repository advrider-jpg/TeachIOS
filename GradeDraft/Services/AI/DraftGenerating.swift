import Foundation
import Synchronization

import FoundationModels

/// The one seam between MarkForMe and the on-device model. Production uses `SystemModelDraftGenerator`;
/// tests use a scripted double.
protocol DraftGenerating: Sendable {
    /// Streams the response, calling `onPartial` with each partially generated value, and returns the complete value.
    func draft<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions, onPartial: @escaping @Sendable (T.PartiallyGenerated) -> Void) async throws -> T
    func respond<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions) async throws -> T
    /// For output whose shape is only known at run time, such as a choice from a list built from the catalogue.
    func respond(schema: GenerationSchema, instructions: String, prompt: String, options: GenerationOptions) async throws -> GeneratedContent
}

/// Wraps `LanguageModelSession` on Apple's on-device `SystemLanguageModel.default`. Each request uses a fresh
/// session, except that a session prepared by `prewarm(instructions:)` is used by the next request with the
/// same instructions.
final class SystemModelDraftGenerator: DraftGenerating {
    private let prewarmed = Mutex<(instructions: String, session: LanguageModelSession)?>(nil)

    /// Deterministic generation: the same packet produces the same draft on the same device (D9).
    static let options = GenerationOptions(samplingMode: .greedy)
    static let samplingDescription = "greedy"

    func prewarm(instructions: String) {
        let session = LanguageModelSession(instructions: instructions)
        session.prewarm()
        prewarmed.withLock { $0 = (instructions, session) }
    }

    func draft<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions, onPartial: @escaping @Sendable (T.PartiallyGenerated) -> Void) async throws -> T {
        let stream = session(for: instructions).streamResponse(to: prompt, generating: type, options: options)
        for try await snapshot in stream {
            onPartial(snapshot.content)
        }
        return try await stream.collect().content
    }

    func respond<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions) async throws -> T {
        try await session(for: instructions).respond(to: prompt, generating: type, options: options).content
    }

    func respond(schema: GenerationSchema, instructions: String, prompt: String, options: GenerationOptions) async throws -> GeneratedContent {
        try await session(for: instructions).respond(to: prompt, schema: schema, options: options).content
    }

    private func session(for instructions: String) -> LanguageModelSession {
        let reused = prewarmed.withLock { stored -> LanguageModelSession? in
            guard let current = stored, current.instructions == instructions else { return nil }
            stored = nil
            return current.session
        }
        return reused ?? LanguageModelSession(instructions: instructions)
    }
}
