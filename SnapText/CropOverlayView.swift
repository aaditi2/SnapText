import UIKit

final class CropOverlayView: UIView {

    // Public: current crop rect (in this view’s coordinate space)
    private(set) var cropRect: CGRect {
        didSet { updateMaskPath() }
    }

    // Area we allow the crop to live in (the visible image frame)
    private let allowedRect: CGRect

    // UI
    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    // Handles
    private let tl = Handle()
    private let tr = Handle()
    private let bl = Handle()
    private let br = Handle()

    private let minSize: CGFloat = 60

    // MARK: - Init
    init(frame: CGRect, allowedRect: CGRect) {
        self.allowedRect = allowedRect
        // initial crop rect = centered, 70% of allowed
        let w = allowedRect.width * 0.7
        let h = allowedRect.height * 0.7
        self.cropRect = CGRect(x: allowedRect.midX - w/2,
                               y: allowedRect.midY - h/2,
                               width: w, height: h)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Expose for controller
    var currentCropRect: CGRect { cropRect }

    // MARK: - Setup
    private func setup() {
        isUserInteractionEnabled = true
        backgroundColor = .clear

        // Dim outside area
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
        layer.addSublayer(maskLayer)

        // Border
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 2
        layer.addSublayer(borderLayer)

        [tl, tr, bl, br].forEach { addSubview($0) }
        positionHandles()

        // Drag whole rect gesture
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPanWhole(_:)))
        addGestureRecognizer(pan)

        // Drag handles
        tl.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPanTL(_:))))
        tr.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPanTR(_:))))
        bl.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPanBL(_:))))
        br.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPanBR(_:))))

        updateMaskPath()
    }

    private func positionHandles() {
        tl.center = cropRect.origin
        tr.center = CGPoint(x: cropRect.maxX, y: cropRect.minY)
        bl.center = CGPoint(x: cropRect.minX, y: cropRect.maxY)
        br.center = CGPoint(x: cropRect.maxX, y: cropRect.maxY)
    }

    private func updateMaskPath() {
        let p = UIBezierPath(rect: bounds)
        let inner = UIBezierPath(roundedRect: cropRect, cornerRadius: 8)
        p.append(inner)
        p.usesEvenOddFillRule = true
        maskLayer.path = p.cgPath

        borderLayer.path = UIBezierPath(roundedRect: cropRect, cornerRadius: 8).cgPath
        positionHandles()
    }

    // MARK: - Pan (whole rect)
    @objc private func didPanWhole(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        g.setTranslation(.zero, in: self)

        var new = cropRect.offsetBy(dx: t.x, dy: t.y)
        // constrain to allowed
        if new.minX < allowedRect.minX { new.origin.x = allowedRect.minX }
        if new.minY < allowedRect.minY { new.origin.y = allowedRect.minY }
        if new.maxX > allowedRect.maxX { new.origin.x = allowedRect.maxX - new.width }
        if new.maxY > allowedRect.maxY { new.origin.y = allowedRect.maxY - new.height }

        cropRect = new
    }

    // MARK: - Pan corners
    @objc private func didPanTL(_ g: UIPanGestureRecognizer) { resize(using: g, corner: .tl) }
    @objc private func didPanTR(_ g: UIPanGestureRecognizer) { resize(using: g, corner: .tr) }
    @objc private func didPanBL(_ g: UIPanGestureRecognizer) { resize(using: g, corner: .bl) }
    @objc private func didPanBR(_ g: UIPanGestureRecognizer) { resize(using: g, corner: .br) }

    private enum Corner { case tl, tr, bl, br }

    private func resize(using g: UIPanGestureRecognizer, corner: Corner) {
        let t = g.translation(in: self)
        g.setTranslation(.zero, in: self)
        var r = cropRect

        switch corner {
        case .tl:
            r.origin.x += t.x
            r.origin.y += t.y
            r.size.width  -= t.x
            r.size.height -= t.y
        case .tr:
            r.origin.y += t.y
            r.size.width  += t.x
            r.size.height -= t.y
        case .bl:
            r.origin.x += t.x
            r.size.width  -= t.x
            r.size.height += t.y
        case .br:
            r.size.width  += t.x
            r.size.height += t.y
        }

        // enforce min size
        if r.width < minSize { r.size.width = minSize }
        if r.height < minSize { r.size.height = minSize }

        // keep top-left pinned for TL/BL, top-right for TR, etc. after min-size clamp
        switch corner {
        case .tl:
            r.origin.x = min(r.origin.x, cropRect.maxX - minSize)
            r.origin.y = min(r.origin.y, cropRect.maxY - minSize)
        case .tr:
            r.origin.y = min(r.origin.y, cropRect.maxY - minSize)
        case .bl:
            r.origin.x = min(r.origin.x, cropRect.maxX - minSize)
        case .br: break
        }

        // constrain to allowedRect
        if r.minX < allowedRect.minX { r.origin.x = allowedRect.minX }
        if r.minY < allowedRect.minY { r.origin.y = allowedRect.minY }
        if r.maxX > allowedRect.maxX { r.size.width = allowedRect.maxX - r.minX }
        if r.maxY > allowedRect.maxY { r.size.height = allowedRect.maxY - r.minY }

        cropRect = r
    }

    // Expose to controller
    var cropRectPublic: CGRect { cropRect }

    // Little circular handle view
    private final class Handle: UIView {
        override init(frame: CGRect) {
            super.init(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
            backgroundColor = .white
            layer.cornerRadius = 9
            layer.borderWidth = 1
            layer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor
            isUserInteractionEnabled = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

// Convenience for controller access
extension CropOverlayView {
    var cropRectValue: CGRect { currentCropRect }
}
