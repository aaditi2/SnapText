import UIKit
import AVFoundation

final class CustomCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    // Callback to SwiftUI with the *cropped* image
    var onCapture: ((UIImage) -> Void)?

    // Camera
    private var session: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!

    // Captured preview
    private var capturedImageView: UIImageView?
    private var cropOverlay: CropOverlayView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    // MARK: Camera setup
    private func setupCamera() {
        // Reset view
        view.subviews.forEach { $0.removeFromSuperview() }
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Shutter button
        let shutter = UIButton(type: .system)
        shutter.setTitle("●", for: .normal)
        shutter.setTitleColor(.white, for: .normal)
        shutter.titleLabel?.font = .systemFont(ofSize: 40, weight: .bold)
        shutter.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        shutter.layer.cornerRadius = 35
        shutter.frame = CGRect(x: (view.bounds.width - 70)/2,
                               y: view.bounds.height - 110,
                               width: 70, height: 70)
        shutter.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        shutter.layer.zPosition = 1000
        view.addSubview(shutter)

        session.startRunning()
    }

    @objc private func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    // MARK: Photo delegate
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        showCapturedImage(image)
    }

    // MARK: Show captured image + crop UI
    private func showCapturedImage(_ image: UIImage) {
        // Normalize to .up so preview space == image space
        let upright = normalizedUp(image)

        session.stopRunning()
        previewLayer.removeFromSuperlayer()
        view.subviews.forEach { $0.removeFromSuperview() }

        let safeBottom = view.safeAreaInsets.bottom
        let buttonHeight: CGFloat = 50
        let spacing: CGFloat = 20
        let availableHeight = view.bounds.height - buttonHeight - spacing - safeBottom - 20

        // AspectFit image view
        let imageFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: availableHeight)
        let iv = UIImageView(image: upright)
        iv.frame = imageFrame
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        view.addSubview(iv)
        capturedImageView = iv

        // Constrain crop to visible image area
        let allowed = imageFrameInImageView(iv)
        let overlay = CropOverlayView(frame: imageFrame, allowedRect: allowed)
        view.addSubview(overlay)
        cropOverlay = overlay

        // Bottom blurred bar + buttons
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        blur.frame = CGRect(x: 0,
                            y: view.bounds.height - buttonHeight - safeBottom - 20,
                            width: view.bounds.width,
                            height: buttonHeight + safeBottom + 20)
        view.addSubview(blur)

        let retake = UIButton(type: .system)
        retake.setTitle("Retake", for: .normal)
        retake.setTitleColor(.white, for: .normal)
        retake.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        retake.backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        retake.layer.cornerRadius = 10
        retake.addTarget(self, action: #selector(retakePhoto), for: .touchUpInside)

        let use = UIButton(type: .system)
        use.setTitle("Use Photo", for: .normal)
        use.setTitleColor(.white, for: .normal)
        use.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        use.backgroundColor = .systemBlue
        use.layer.cornerRadius = 10
        use.addTarget(self, action: #selector(cropAndReturn), for: .touchUpInside)

        let w = (view.bounds.width - 60)/2
        let y = view.bounds.height - safeBottom - buttonHeight - 10
        retake.frame = CGRect(x: 20, y: y, width: w, height: buttonHeight)
        use.frame    = CGRect(x: retake.frame.maxX + 20, y: y, width: w, height: buttonHeight)
        [retake, use].forEach { $0.layer.zPosition = 1000; view.addSubview($0) }
    }

    @objc private func retakePhoto() { setupCamera() }

    @objc private func cropAndReturn() {
        guard let img = capturedImageView?.image,           // already normalized upright
              let iv  = capturedImageView,
              let overlay = cropOverlay else { return }

        // 1) Visible aspectFit rect (in view coords)
        let visible = imageFrameInImageView(iv)

        // 2) Crop rect from overlay (in view coords)
        let r = overlay.cropRectValue

        // 3) Normalize to 0..1 within visible rect
        let nx = (r.minX - visible.minX) / visible.width
        let ny = (r.minY - visible.minY) / visible.height
        let nw = r.width / visible.width
        let nh = r.height / visible.height

        // 4) Map normalized → image-space (upright image)
        let rectInImage = CGRect(
            x: nx * img.size.width,
            y: ny * img.size.height,
            width:  nw * img.size.width,
            height: nh * img.size.height
        ).integral

        // 5) Crop using renderer (robust to orientation)
        let cropped = cropImage(img, to: rectInImage)
        onCapture?(cropped)
        dismiss(animated: true)
    }

    // MARK: Helpers

    /// Actual drawn rect for an aspectFit image inside the UIImageView
    private func imageFrameInImageView(_ iv: UIImageView) -> CGRect {
        guard let img = iv.image else { return .zero }
        let viewSize = iv.bounds.size
        let imgSize = img.size
        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let width  = imgSize.width * scale
        let height = imgSize.height * scale
        let x = (viewSize.width - width)  * 0.5 + iv.frame.minX
        let y = (viewSize.height - height) * 0.5 + iv.frame.minY
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Normalize EXIF orientation to `.up`
    private func normalizedUp(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = image.scale
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Crop via renderer (respects orientation)
    private func cropImage(_ image: UIImage, to rectInImageSpace: CGRect) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = image.scale
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: rectInImageSpace.size, format: fmt).image { _ in
            image.draw(at: CGPoint(x: -rectInImageSpace.origin.x,
                                   y: -rectInImageSpace.origin.y))
        }
    }
}
