//
//  TableDetector.swift
//  SnapText
//
//  Heuristic table detector built on Vision OCR word boxes.
//  Produces a 2D grid of strings suitable for a simple spreadsheet UI.
//

import UIKit
import Vision

public struct DetectedTable {
    public var rows: [[String]]        // 2D grid of cell strings
    public var sourceImage: UIImage?    // optional for debugging / preview
}

public enum TableDetectMode {
    case fast      // looser grouping
    case strict    // tighter grouping (fewer merges)
}

public final class TableDetector {

    // MARK: - Entry point

    /// Synchronously detect a rough table layout from an image.
    /// Returns nil if OCR fails or we can't find at least 2 columns + 2 rows.
    public static func detect(from image: UIImage,
                              mode: TableDetectMode = .fast) -> DetectedTable? {

        guard let cg = image.cgImage else { return nil }

        // 1) OCR
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        var observations: [VNRecognizedTextObservation] = []
        let req = VNRecognizeTextRequest { r, _ in
            observations = (r.results as? [VNRecognizedTextObservation]) ?? []
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        if #available(iOS 16.0, *) { req.revision = VNRecognizeTextRequestRevision3 }

        do { try handler.perform([req]) } catch { return nil }
        if observations.isEmpty { return nil }

        // 2) Word boxes in IMAGE coordinates
        let words = wordsInImageSpace(from: observations, imageSize: CGSize(width: cg.width, height: cg.height))
        if words.isEmpty { return nil }

        // 3) Group words into visual rows (by y-centers)
        let rowToleranceScale: CGFloat = (mode == .strict) ? 0.45 : 0.65
        let rowsOfWords = makeRows(words: words, toleranceScale: rowToleranceScale)
        guard rowsOfWords.count >= 2 else { return nil }

        // 4) Decide columns via 1-D k-means over x-centers (estimate K from the widest row)
        let estimatedK = rowsOfWords.map { $0.count }.max() ?? 1
        if estimatedK < 2 { return nil }

        let allXCenters: [CGFloat] = rowsOfWords.flatMap { $0.map { $0.rect.midX } }
        let centers = kMeans1D(points: allXCenters, k: estimatedK)
        if centers.count < 2 { return nil }

        // 5) Assign each word to the nearest column center; build a grid
        let grid = buildGrid(rowsOfWords: rowsOfWords, columnCenters: centers)

        // Require at least 2x2 with some text
        let hasAnyText = grid.flatMap { $0 }.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard grid.count >= 2, (grid.first?.count ?? 0) >= 2, hasAnyText else { return nil }

        return DetectedTable(rows: grid, sourceImage: image)
    }

    // MARK: - Internal types

    private struct WordBox {
        let text: String
        let rect: CGRect   // in image space (points/pixels of the CGImage size)
    }

    // MARK: - OCR → Word boxes

    private static func wordsInImageSpace(from obs: [VNRecognizedTextObservation],
                                          imageSize: CGSize) -> [WordBox] {

        var out: [WordBox] = []
        out.reserveCapacity(obs.count)

        for o in obs {
            guard let top = o.topCandidates(1).first else { continue }
            var b = o.boundingBox          // Vision normalized (origin bottom-left)
            // Convert to image-space rect (origin top-left)
            // First normalize to image coords with origin bottom-left:
            let imgRectBL = CGRect(x: b.minX * imageSize.width,
                                   y: b.minY * imageSize.height,
                                   width: b.width * imageSize.width,
                                   height: b.height * imageSize.height)
            // Flip to top-left origin:
            let imgRectTL = CGRect(x: imgRectBL.minX,
                                   y: imageSize.height - imgRectBL.maxY,
                                   width: imgRectBL.width,
                                   height: imgRectBL.height)

            out.append(WordBox(text: top.string, rect: imgRectTL))
        }
        return out
    }

    // MARK: - Row grouping

    /// Groups words into rows using a tolerance scaled by the median word height.
    private static func makeRows(words: [WordBox], toleranceScale: CGFloat) -> [[WordBox]] {
        guard !words.isEmpty else { return [] }

        let heights = words.map { $0.rect.height }
        let hMed = max(8, medianCGFloat(heights)) // guard tiny heights

        let tol = max(6, hMed * toleranceScale)

        // Sort by vertical position (top to bottom → increasing y)
        let sorted = words.sorted { $0.rect.midY < $1.rect.midY }

        var rows: [[WordBox]] = []
        for w in sorted {
            if var last = rows.last, let anchor = last.first {
                if abs(w.rect.midY - anchor.rect.midY) <= tol {
                    last.append(w)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([w])
        }

        // Sort each row left → right
        for i in rows.indices {
            rows[i].sort { $0.rect.minX < $1.rect.minX }
        }
        return rows
    }

    // MARK: - Build grid by assigning to nearest column center

    private static func buildGrid(rowsOfWords: [[WordBox]], columnCenters: [CGFloat]) -> [[String]] {
        let K = columnCenters.count
        let centers = columnCenters.sorted()

        var grid: [[String]] = Array(repeating: Array(repeating: "", count: K), count: rowsOfWords.count)

        for (ri, row) in rowsOfWords.enumerated() {
            for w in row {
                let cx = w.rect.midX
                // nearest center index
                var best = 0
                var bestDist = abs(cx - centers[0])
                for i in 1..<K {
                    let d = abs(cx - centers[i])
                    if d < bestDist { bestDist = d; best = i }
                }

                if grid[ri][best].isEmpty {
                    grid[ri][best] = normalizeCellText(w.text)
                } else {
                    // if two words land in same column cell, concatenate with a space
                    grid[ri][best] += " " + normalizeCellText(w.text)
                }
            }
        }

        // Trim outer empty columns (rare but can happen)
        grid = trimEmptyOuterColumns(grid)

        return grid
    }

    private static func normalizeCellText(_ s: String) -> String {
        // Collapse runs of whitespace (keep it simple; avoid regex dependency issues)
        let pieces = s.split(whereSeparator: { $0.isWhitespace })
        return pieces.joined(separator: " ")
    }

    private static func trimEmptyOuterColumns(_ grid: [[String]]) -> [[String]] {
        guard let cols = grid.first?.count, cols > 0 else { return grid }

        // find first non-empty col
        var left = 0
        while left < cols {
            let empty = grid.allSatisfy { row in
                row.indices.contains(left) ? row[left].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true
            }
            if !empty { break }
            left += 1
        }
        // find last non-empty col
        var right = cols - 1
        while right >= left {
            let empty = grid.allSatisfy { row in
                row.indices.contains(right) ? row[right].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true
            }
            if !empty { break }
            right -= 1
        }
        if left == 0 && right == cols - 1 { return grid }
        if right < left { return grid } // all empty, keep as-is

        return grid.map { Array($0[left...right]) }
    }

    // MARK: - Utilities

    // Disambiguated medians
    private static func medianInt(_ xs: [Int]) -> Int {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let m = s.count / 2
        if s.count % 2 == 0 { return (s[m - 1] + s[m]) / 2 }
        return s[m]
    }

    private static func medianCGFloat(_ xs: [CGFloat]) -> CGFloat {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let m = s.count / 2
        if s.count % 2 == 0 { return (s[m - 1] + s[m]) / 2.0 }
        return s[m]
    }

    /// Simple 1-D k-means returning sorted cluster centers.
    private static func kMeans1D(points: [CGFloat], k: Int, maxIter: Int = 20) -> [CGFloat] {
        guard !points.isEmpty, k >= 1 else { return [] }
        let pts = points.sorted()

        // init centers using quantiles
        var centers: [CGFloat] = (0..<k).map { i in
            let t   = CGFloat(i) / CGFloat(max(1, k - 1))
            let idx = Int(t * CGFloat(pts.count - 1))
            return pts[idx]
        }

        for _ in 0..<maxIter {
            // assign
            var buckets = Array(repeating: [CGFloat](), count: k)
            for p in pts {
                var best = 0
                var bestDist = abs(p - centers[0])
                for c in 1..<k {
                    let d = abs(p - centers[c])
                    if d < bestDist { bestDist = d; best = c }
                }
                buckets[best].append(p)
            }
            // recompute
            var changed = false
            for c in 0..<k {
                let bucket = buckets[c]
                if bucket.isEmpty { continue }
                let newCenter = medianCGFloat(bucket)
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
