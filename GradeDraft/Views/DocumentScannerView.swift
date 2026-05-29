import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void
    var onCancel: () -> Void
    var onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel, onError: onError)
    }

    // @unchecked Sendable: Coordinator only stores immutable callbacks; UIKit guarantees
    // all VNDocumentCameraViewControllerDelegate calls arrive on the main thread.
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate, @unchecked Sendable {
        private let onComplete: ([UIImage]) -> Void
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Extract images here (nonisolated) so non-Sendable VNDocumentCameraScan is
            // never sent into the @MainActor region. UIImage is Sendable.
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            MainActor.assumeIsolated {
                controller.dismiss(animated: true) { self.onComplete(images) }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true) { self.onCancel() }
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true) { self.onError(error) }
            }
        }
    }
}
