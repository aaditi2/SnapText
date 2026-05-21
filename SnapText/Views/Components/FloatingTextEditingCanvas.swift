import SwiftUI
import UIKit

struct FloatingTextEditingCanvas: View {
    @Binding var text: String
    @State private var selectionRects: [CGRect] = []
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    private let canvasPadding: CGFloat = 22

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { _ in
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 18)

                    FloatingTextViewRepresentable(
                        text: $text,
                        selectionRects: $selectionRects,
                        selectedRange: $selectedRange
                    )
                    .padding(EdgeInsets(top: canvasPadding, leading: canvasPadding, bottom: canvasPadding, trailing: canvasPadding))

                    SelectionOverlay(selectionRects: selectionRects)
                        .padding(EdgeInsets(top: canvasPadding, leading: canvasPadding, bottom: canvasPadding, trailing: canvasPadding))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 260, maxHeight: .infinity)

        }
    }

}

// MARK: - Selection Overlay

private struct SelectionOverlay: View {
    var selectionRects: [CGRect]

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                ForEach(Array(selectionRects.enumerated()), id: \.offset) { _, rect in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.yellow.opacity(0.25))
                        .frame(width: max(rect.width, 2), height: max(rect.height, 12))
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                if let start = selectionRects.first {
                    SelectionHandle()
                        .position(x: start.minX, y: start.minY)
                        .allowsHitTesting(false)
                }
                if let end = selectionRects.last {
                    SelectionHandle()
                        .position(x: end.maxX, y: end.maxY)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct SelectionHandle: View {
    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.yellow)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow)
                .frame(width: 3, height: 20)
        }
    }
}


// MARK: - UITextView Bridge

private struct FloatingTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectionRects: [CGRect]
    @Binding var selectedRange: NSRange

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor.white
        textView.tintColor = UIColor.systemYellow
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.indicatorStyle = .white
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FloatingTextViewRepresentable

        init(_ parent: FloatingTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            parent.selectedRange = range

            guard let textRange = textView.selectedTextRange else {
                parent.selectionRects = []
                return
            }
            let rects = textView.selectionRects(for: textRange)
                .map { selectionRect -> CGRect in
                    var rect = selectionRect.rect
                    rect.origin.x -= textView.contentOffset.x
                    rect.origin.y -= textView.contentOffset.y
                    rect.origin.x += textView.textContainerInset.left
                    rect.origin.y += textView.textContainerInset.top
                    return rect
                }
                .filter { !$0.isNull && !$0.isInfinite && !$0.isEmpty }

            Task { @MainActor in
                self.parent.selectionRects = rects
            }
        }
    }
}
