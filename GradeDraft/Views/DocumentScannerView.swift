import SwiftUI
import UIKit
import VisionKit

/// Presents the document camera. It never dismisses itself: the presenting view receives
/// `onComplete`, `onCancel` or `onError` and closes the sheet by setting its own binding.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([CGImage]) -> Void
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

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let onComplete: ([CGImage]) -> Void
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(onComplete: @escaping ([CGImage]) -> Void, onCancel: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [CGImage] = []
            for index in 0..<scan.pageCount {
                guard let image = scan.imageOfPage(at: index).cgImage else {
                    onError(ImportError.imageUnreadable)
                    return
                }
                images.append(image)
            }
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onError(error)
        }
    }
}
