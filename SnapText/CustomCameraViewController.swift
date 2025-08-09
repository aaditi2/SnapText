import UIKit
import AVFoundation

class CustomCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    var onPhotoCropped: ((UIImage) -> Void)?

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!

    private var capturedImageView: UIImageView?
    private var cropOverlay: CropOverlayView?
    private var captureButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Camera input failed")
            return
        }
        captureSession.addInput(videoInput)

        photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else {
            print("Photo output failed")
            return
        }
        captureSession.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Capture button
        let btn = UIButton(type: .system)
        btn.setTitle("●", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 40, weight: .regular)
        btn.frame = CGRect(x: (view.bounds.width - 70) / 2, y: view.bounds.height - 100, width: 70, height: 70)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 35
        btn.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(btn)
        self.captureButton = btn

        captureSession.startRunning()
    }

    // MARK: - Capture
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Failed to capture image: \(String(describing: error))")
            return
        }
        showCapturedImage(image)
    }

    // MARK: - Captured UI (image + overlay + buttons)
    private func showCapturedImage(_ image: UIImage) {
        // Stop camera preview
        captureSession.stopRunning()
        previewLayer.removeFromSuperlayer()
        view.subviews.forEach { $0.removeFromSuperview() }

        // Layout constants
        let safeBottom: CGFloat = view.safeAreaInsets.bottom
        let buttonHeight: CGFloat = 50
        let spacing: CGFloat = 20
        let availableHeight = view.bounds.height - buttonHeight - spacing - safeBottom - 20

        // Image view occupies the top area, aspectFit
        let imageFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: availableHeight)
        let imageView = UIImageView(image: image)
        imageView.frame = imageFrame
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        view.addSubview(imageView)
        self.capturedImageView = imageView

        // Compute the *visible* image rect inside the imageView (aspectFit)
        let visibleRect = imageFrameInImageView(imageView)

        // Overlay constrained to the visible image rect
        let overlay = CropOverlayView(frame: imageFrame, allowedRect: visibleRect)
        view.addSubview(overlay)
        self.cropOverlay = overlay

        // Blurred button bar background
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(
            x: 0,
            y: view.bounds.height - buttonHeight - safeBottom - 20,
            width: view.bounds.width,
            height: buttonHeight + safeBottom + 20
        )
        view.addSubview(blurView)

        // Retake button
        let retakeButton = UIButton(type: .system)
        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.setTitleColor(.white, for: .normal)
        retakeButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        retakeButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        retakeButton.layer.cornerRadius = 10
        retakeButton.addTarget(self, action: #selector(retakePhoto), for: .touchUpInside)

        // Use Photo button
        let useButton = UIButton(type: .system)
        useButton.setTitle("Use Photo", for: .normal)
        useButton.setTitleColor(.white, for: .normal)
        useButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        useButton.backgroundColor = UIColor.systemBlue
        useButton.layer.cornerRadius = 10
        useButton.addTarget(self, action: #selector(cropAndReturn), for: .touchUpInside)

        // Layout side-by-side
        let buttonWidth = (view.bounds.width - 60) / 2
        let y = view.bounds.height - safeBottom - buttonHeight - 10
        retakeButton.frame = CGRect(x: 20, y: y, width: buttonWidth, height: buttonHeight)
        useButton.frame = CGRect(x: retakeButton.frame.maxX + 20, y: y, width: buttonWidth, height: buttonHeight)

        view.addSubview(retakeButton)
        view.addSubview(useButton)
    }

    // MARK: - Actions
    @objc private func retakePhoto() {
        setupCamera()
    }

    @objc private func cropAndReturn() {
        guard let image = capturedImageView?.image,
              let imageView = capturedImageView,
              let overlay = cropOverlay else { return }

        let visible = imageFrameInImageView(imageView)
        let cropR = overlay.cropRect

        // Normalize to image space
        let nx = (cropR.minX - visible.minX) / visible.width
        let ny = (cropR.minY - visible.minY) / visible.height
        let nw = cropR.width / visible.width
        let nh = cropR.height / visible.height

        var imageCropRect = CGRect(
            x: nx * image.size.width,
            y: ny * image.size.height,
            width: nw * image.size.width,
            height: nh * image.size.height
        ).integral

        if let cg = image.cgImage {
            imageCropRect = imageCropRect.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            if let croppedCG = cg.cropping(to: imageCropRect) {
                let cropped = UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
                onPhotoCropped?(cropped)
                dismiss(animated: true)
                return
            }
        }

        onPhotoCropped?(image) // fallback
        dismiss(animated: true)
    }

    // MARK: - Helpers
    /// Actual drawn image rect inside an aspectFit UIImageView
    private func imageFrameInImageView(_ iv: UIImageView) -> CGRect {
        guard let img = iv.image else { return .zero }
        let viewSize = iv.bounds.size
        let imgSize = img.size
        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let width = imgSize.width * scale
        let height = imgSize.height * scale
        let x = (viewSize.width - width) * 0.5 + iv.frame.minX
        let y = (viewSize.height - height) * 0.5 + iv.frame.minY
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
