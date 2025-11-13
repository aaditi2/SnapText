import SwiftUI
import UIKit

struct FloatingTextEditingCanvas: View {
    @Binding var text: String
    @State private var selectionRects: [CGRect] = []
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isDictating = false
    @State private var dictationBuffer: String = ""
    @State private var handwritingBuffer: String = ""

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

                    dictationControl
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(dictationOverlay)
            }
            .frame(minHeight: 260, maxHeight: .infinity)

            suggestionBar

            handwritingPanel
        }
    }

    @ViewBuilder
    private var dictationControl: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDictating.toggle()
                dictationBuffer = ""
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                Text(isDictating ? "Stop" : "Dictate")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(.top, 16)
        .padding(.trailing, 16)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dictationOverlay: some View {
        if isDictating {
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Dictation", systemImage: "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button("Insert") {
                            applyDictation()
                        }
                        .font(.system(size: 15, weight: .semibold))
                    }
                    Text("Simulated listening… Type what you would say to insert it into the text.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    TextEditor(text: $dictationBuffer)
                        .frame(height: 90)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 18)
                )
                .padding(24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func applyDictation() {
        let trimmed = dictationBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let safeLocation = max(0, min(selectedRange.location, text.count))
        let safeLength = max(0, min(selectedRange.length, text.count - safeLocation))
        let replacementRange = NSRange(location: safeLocation, length: safeLength)

        if let range = Range(replacementRange, in: text) {
            let startOffset = range.lowerBound.utf16Offset(in: text)
            text.replaceSubrange(range, with: trimmed)
            selectedRange = NSRange(location: startOffset + trimmed.count, length: 0)
        }

        dictationBuffer = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            isDictating = false
        }
    }

    @ViewBuilder
    private var suggestionBar: some View {
        let suggestions = suggestionCandidates()
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            applySuggestion(suggestion)
                        }) {
                            Text(suggestion)
                                .font(.system(size: 15, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 44)
        }
    }

    private func suggestionCandidates() -> [String] {
        let words = text.split(whereSeparator: { !$0.isLetter })
        guard let last = words.last else { return ["Check", "Correct", "Clean"] }
        let base = String(last)
        var ordered: [String] = []
        func appendUnique(_ candidate: String) {
            if !ordered.contains(candidate) {
                ordered.append(candidate)
            }
        }
        if base.count > 3 {
            appendUnique(base.capitalized)
            appendUnique(base.lowercased())
            appendUnique(base + "?")
            appendUnique(base + "!")
        } else {
            ["Correct", "Review", "Confirm"].forEach(appendUnique)
        }
        return Array(ordered.prefix(5))
    }

    private func applySuggestion(_ suggestion: String) {
        if let range = rangeOfLastEditableWord(in: text) {
            let startOffset = range.lowerBound.utf16Offset(in: text)
            text.replaceSubrange(range, with: suggestion)
            selectedRange = NSRange(location: startOffset + suggestion.count, length: 0)
        } else {
            text = suggestion
            selectedRange = NSRange(location: suggestion.count, length: 0)
        }
    }


    private func rangeOfLastEditableWord(in value: String) -> Range<String.Index>? {
        var end = value.endIndex
        while end > value.startIndex {
            let previous = value.index(before: end)
            if value[previous].isWhitespace || value[previous].isNewline {
                end = previous
                continue
            }
            var cursor = previous
            var start = previous
            while cursor > value.startIndex {
                let before = value.index(before: cursor)
                if value[before].isWhitespace || value[before].isNewline {
                    break
                }
                cursor = before
                start = before
            }
            let rangeEnd = value.index(after: previous)
            return start..<rangeEnd
        }
        return nil
    }


    @ViewBuilder
    private var handwritingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Handwriting Correction", systemImage: "pencil.and.outline")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Apply") {
                    applyHandwriting()
                }
                .font(.system(size: 14, weight: .semibold))
            }
            Text("Jot quick pen-style corrections — we will drop them at your cursor.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.65))
            HandwritingInputField(text: $handwritingBuffer)
                .frame(height: 110)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func applyHandwriting() {
        let trimmed = handwritingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let safeLocation = max(0, min(selectedRange.location, text.count))
        if let insertionIndex = text.index(text.startIndex, offsetBy: safeLocation, limitedBy: text.endIndex) {
            text.insert(contentsOf: (safeLocation == 0 ? "" : " ") + trimmed, at: insertionIndex)
            selectedRange = NSRange(location: safeLocation + trimmed.count + (safeLocation == 0 ? 0 : 1), length: 0)
        }
        handwritingBuffer = ""
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

// MARK: - Handwriting Input

private struct HandwritingInputField: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    Canvas { context, size in
                        let gridSpacing: CGFloat = 18
                        var path = Path()
                        var y: CGFloat = gridSpacing
                        while y < size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            y += gridSpacing
                        }
                        context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
                    }
                )
            TextEditor(text: $text)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.95))
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

            DispatchQueue.main.async {
                self.parent.selectionRects = rects
            }
        }
    }
}
