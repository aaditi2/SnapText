import UIKit
import Vision

public struct DetectedTable {
    public var rows: [[String]]
    public var sourceImage: UIImage?
}

public enum TableDetectMode {
    case fast, strict
}

public final actor TableDetector {
    // MARK: - Async Entry Point (modern)
    public static func detect(
        from image: UIImage,
        mode: TableDetectMode = .fast
    ) async -> DetectedTable? {
        guard let cg = image.cgImage else { return nil }

        do {
            // 1️⃣ Perform OCR asynchronously
            let observations = try await performOCR(cgImage: cg)
            guard !observations.isEmpty else { return nil }

            // 2️⃣ Word boxes in image coordinates
            let words = wordsInImageSpace(from: observations,
                                          imageSize: CGSize(width: cg.width, height: cg.height))
            guard !words.isEmpty else { return nil }

            // 3️⃣ Group into rows
            let rowToleranceScale: CGFloat = (mode == .strict) ? 0.45 : 0.65
            let rowsOfWords = makeRows(words: words, toleranceScale: rowToleranceScale)
            guard rowsOfWords.count >= 2 else { return nil }

            // 4️⃣ Column centers via lightweight k-means
            let estimatedK = rowsOfWords.map { $0.count }.max() ?? 1
            guard estimatedK >= 2 else { return nil }

            let allXCenters = rowsOfWords.flatMap { $0.map { $0.rect.midX } }
            let centers = (allXCenters.count > 50)
                ? kMeans1D(points: allXCenters, k: estimatedK)
                : Array(allXCenters.prefix(estimatedK)).sorted()

            guard centers.count >= 2 else { return nil }

            // 5️⃣ Build grid
            let grid = buildGrid(rowsOfWords: rowsOfWords, columnCenters: centers)
            let hasAnyText = grid.flatMap { $0 }.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard grid.count >= 2, (grid.first?.count ?? 0) >= 2, hasAnyText else { return nil }

            return DetectedTable(rows: grid, sourceImage: image)
        } catch {
            print("⚠️ TableDetector failed: \(error)")
            return nil
        }
    }

    // MARK: - OCR Helper (async Vision)
    private static func performOCR(cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let results = request.results ?? []
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Word Conversion
    private struct WordBox {
        let text: String
        let rect: CGRect
    }

    private static func wordsInImageSpace(from obs: [VNRecognizedTextObservation], imageSize: CGSize) -> [WordBox] {
        var out: [WordBox] = []
        out.reserveCapacity(obs.count)

        for o in obs {
            guard let top = o.topCandidates(1).first else { continue }
            let b = o.boundingBox
            let imgRectBL = CGRect(x: b.minX * imageSize.width,
                                   y: b.minY * imageSize.height,
                                   width: b.width * imageSize.width,
                                   height: b.height * imageSize.height)
            let imgRectTL = CGRect(x: imgRectBL.minX,
                                   y: imageSize.height - imgRectBL.maxY,
                                   width: imgRectBL.width,
                                   height: imgRectBL.height)
            out.append(WordBox(text: top.string, rect: imgRectTL))
        }
        return out
    }

    // MARK: - Row Grouping
    private static func makeRows(words: [WordBox], toleranceScale: CGFloat) -> [[WordBox]] {
        guard !words.isEmpty else { return [] }

        let hMed = max(8, medianCGFloat(words.map { $0.rect.height }))
        let tol = max(6, hMed * toleranceScale)
        let sorted = words.sorted { $0.rect.midY < $1.rect.midY }

        var rows: [[WordBox]] = []
        for w in sorted {
            if var last = rows.last, let anchor = last.first,
               abs(w.rect.midY - anchor.rect.midY) <= tol {
                last.append(w)
                rows[rows.count - 1] = last
            } else {
                rows.append([w])
            }
        }

        for i in rows.indices { rows[i].sort { $0.rect.minX < $1.rect.minX } }
        return rows
    }

    // MARK: - Grid Construction
    private static func buildGrid(rowsOfWords: [[WordBox]], columnCenters: [CGFloat]) -> [[String]] {
        let K = columnCenters.count
        let centers = columnCenters.sorted()
        var grid = Array(repeating: Array(repeating: "", count: K), count: rowsOfWords.count)

        for (ri, row) in rowsOfWords.enumerated() {
            for w in row {
                let cx = w.rect.midX
                let best = centers.enumerated().min(by: { abs(cx - $0.element) < abs(cx - $1.element) })?.offset ?? 0
                grid[ri][best] = grid[ri][best].isEmpty
                    ? normalizeCellText(w.text)
                    : grid[ri][best] + " " + normalizeCellText(w.text)
            }
        }
        return trimEmptyOuterColumns(grid)
    }

    // MARK: - Helpers
    private static func normalizeCellText(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func trimEmptyOuterColumns(_ grid: [[String]]) -> [[String]] {
        guard let cols = grid.first?.count, cols > 0 else { return grid }
        var left = 0, right = cols - 1
        while left < cols && grid.allSatisfy({ $0[left].trimmingCharacters(in: .whitespaces).isEmpty }) { left += 1 }
        while right >= left && grid.allSatisfy({ $0[right].trimmingCharacters(in: .whitespaces).isEmpty }) { right -= 1 }
        return (left == 0 && right == cols - 1) ? grid : grid.map { Array($0[left...right]) }
    }

    private static func medianCGFloat(_ xs: [CGFloat]) -> CGFloat {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted(); let m = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2.0 : s[m]
    }

    private static func kMeans1D(points: [CGFloat], k: Int, maxIter: Int = 20) -> [CGFloat] {
        guard !points.isEmpty, k >= 1 else { return [] }
        let pts = points.sorted()
        var centers = (0..<k).map { i -> CGFloat in
            let t = CGFloat(i) / CGFloat(max(1, k - 1))
            let idx = Int(t * CGFloat(pts.count - 1))
            return pts[idx]
        }

        for _ in 0..<maxIter {
            var buckets = Array(repeating: [CGFloat](), count: k)
            for p in pts {
                let best = centers.enumerated().min(by: { abs(p - $0.element) < abs(p - $1.element) })!.offset
                buckets[best].append(p)
            }

            var changed = false
            for c in 0..<k where !buckets[c].isEmpty {
                let newCenter = medianCGFloat(buckets[c])
                if newCenter != centers[c] {
                    centers[c] = newCenter
                    changed = true
                }
            }
            if !changed { break }
        }
        return centers.sorted()
    }
}
