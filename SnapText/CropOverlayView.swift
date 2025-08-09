import UIKit

final class CropOverlayView: UIView {

    // The visible image frame inside the big view (aspectFit rect).
    private let allowedRect: CGRect

    // Current crop rect (always clamped inside allowedRect)
    private(set) var cropRect: CGRect

    // Corner handles
    private let handleSize: CGFloat = 22
    private lazy var handles: [UIView] = (0..<4).map { _ in UIView() }

    // Pan to move the entire cropRect
    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanWhole(_:)))

    init(frame: CGRect, allowedRect: CGRect, initialCrop: CGRect? = nil) {
        self.allowedRect = allowedRect
        // Default to 70% of allowedRect if no initial rect provided
        let defaultRect = allowedRect.insetBy(dx: allowedRect.width * 0.15, dy: allowedRect.height * 0.15)
        self.cropRect = initialCrop?.intersection(allowedRect) ?? defaultRect
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear

        addGestureRecognizer(panGesture)
        setupHandles()
        updateHandlePositions()
        setNeedsDisplay()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Drawing: box + dimmed outside
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Dim everything outside cropRect
        ctx.saveGState()
        let outsidePath = UIBezierPath(rect: bounds)
        let cutoutPath = UIBezierPath(rect: cropRect)
        outsidePath.append(cutoutPath)
        outsidePath.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.5).setFill()
        outsidePath.fill()
        ctx.restoreGState()

        // Crop rectangle border
        let border = UIBezierPath(rect: cropRect)
        border.lineWidth = 2
        UIColor.white.setStroke()
        border.stroke()

        // Optional: rule-of-thirds grid
        UIColor.white.withAlphaComponent(0.4).setStroke()
        let grid = UIBezierPath()
        // vertical thirds
        grid.move(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.minY))
        grid.addLine(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.maxY))
        grid.move(to: CGPoint(x: cropRect.minX + 2 * cropRect.width / 3, y: cropRect.minY))
        grid.addLine(to: CGPoint(x: cropRect.minX + 2 * cropRect.width / 3, y: cropRect.maxY))
        // horizontal thirds
        grid.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height / 3))
        grid.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height / 3))
        grid.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + 2 * cropRect.height / 3))
        grid.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + 2 * cropRect.height / 3))
        grid.lineWidth = 1
        grid.stroke()
    }

    // MARK: - Handles
    private func setupHandles() {
        for (i, h) in handles.enumerated() {
            h.backgroundColor = .white
            h.layer.cornerRadius = handleSize / 2
            h.layer.borderWidth = 1
            h.layer.borderColor = UIColor.black.cgColor
            h.frame.size = CGSize(width: handleSize, height: handleSize)
            h.isUserInteractionEnabled = true
            addSubview(h)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanCorner(_:)))
            pan.name = "\(i)" // 0 TL, 1 TR, 2 BL, 3 BR
            h.addGestureRecognizer(pan)
        }
    }

    private func updateHandlePositions() {
        // 0: TL, 1: TR, 2: BL, 3: BR
        handles[0].center = CGPoint(x: cropRect.minX, y: cropRect.minY)
        handles[1].center = CGPoint(x: cropRect.maxX, y: cropRect.minY)
        handles[2].center = CGPoint(x: cropRect.minX, y: cropRect.maxY)
        handles[3].center = CGPoint(x: cropRect.maxX, y: cropRect.maxY)
    }

    // MARK: - Gestures
    @objc private func handlePanCorner(_ g: UIPanGestureRecognizer) {
        let idx = Int(g.name ?? "") ?? 0
        let t = g.translation(in: self)
        g.setTranslation(.zero, in: self)

        var r = cropRect
        let minSize: CGFloat = 60

        switch idx {
        case 0: // top-left
            r.origin.x += t.x
            r.origin.y += t.y
            r.size.width -= t.x
            r.size.height -= t.y
        case 1: // top-right
            r.origin.y += t.y
            r.size.width += t.x
            r.size.height -= t.y
        case 2: // bottom-left
            r.origin.x += t.x
            r.size.width -= t.x
            r.size.height += t.y
        default: // 3 bottom-right
            r.size.width += t.x
            r.size.height += t.y
        }

        // Enforce min size
        if r.width < minSize { r.size.width = minSize }
        if r.height < minSize { r.size.height = minSize }

        // Clamp inside allowedRect
        if r.minX < allowedRect.minX { r.origin.x = allowedRect.minX }
        if r.minY < allowedRect.minY { r.origin.y = allowedRect.minY }
        if r.maxX > allowedRect.maxX { r.origin.x = allowedRect.maxX - r.width }
        if r.maxY > allowedRect.maxY { r.origin.y = allowedRect.maxY - r.height }

        cropRect = r
        updateHandlePositions()
        setNeedsDisplay()
    }

    @objc private func handlePanWhole(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        g.setTranslation(.zero, in: self)

        var r = cropRect
        r.origin.x += t.x
        r.origin.y += t.y

        // Clamp inside allowedRect
        if r.minX < allowedRect.minX { r.origin.x = allowedRect.minX }
        if r.minY < allowedRect.minY { r.origin.y = allowedRect.minY }
        if r.maxX > allowedRect.maxX { r.origin.x = allowedRect.maxX - r.width }
        if r.maxY > allowedRect.maxY { r.origin.y = allowedRect.maxY - r.height }

        cropRect = r
        updateHandlePositions()
        setNeedsDisplay()
    }
}
