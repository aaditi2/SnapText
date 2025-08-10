import SwiftUI

struct CustomCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void   // returns the CROPPED image

    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let vc = CustomCameraViewController()
        vc.onCapture = onCapture
        return vc
    }

    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {}
}
