@preconcurrency import AVFoundation
import SwiftUI

/// Full-bleed live camera preview (AVFoundation) hosted in a `UIViewController`
/// and bridged to SwiftUI. A capture is triggered by flipping `shouldCapture`;
/// the resulting raw JPEG `Data` is handed back through `onCapture`.
struct CameraView: UIViewControllerRepresentable {
    let onCapture: @MainActor (Data) -> Void
    @Binding var shouldCapture: Bool

    /// Whether a back camera exists — false on the simulator, where the caller
    /// should show a fallback instead of a black preview.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if shouldCapture {
            uiViewController.capturePhoto()
            DispatchQueue.main.async { shouldCapture = false }
        }
    }
}

@MainActor
final class CameraViewController: UIViewController {
    var onCapture: (@MainActor (Data) -> Void)?

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let delegateHandler = PhotoCaptureDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        delegateHandler.viewController = self
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else { return }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegateHandler)
    }

    func handleCapturedPhoto(_ data: Data) {
        onCapture?(data)
    }
}

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    @MainActor weak var viewController: CameraViewController?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            self.viewController?.handleCapturedPhoto(data)
        }
    }
}
