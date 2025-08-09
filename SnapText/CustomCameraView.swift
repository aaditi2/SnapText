import SwiftUI

struct CustomCameraView: UIViewControllerRepresentable {
    var completion: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let vc = CustomCameraViewController()
        vc.onPhotoCropped = { image in
            completion(image)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {}
}
