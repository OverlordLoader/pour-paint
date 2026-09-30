import Foundation

/// Number of bands the canvas tube holds. No target ever exceeds this.
let canvasCapacity = 6

// MARK: - Model

/// One pour adds a single band of the tapped supply color onto the canvas.
struct PaintPour: Equatable {
    let supplyIndex: Int
    let color: Int
}

/// A generated level: replicate `target` (color ids, bottom -> top) in the
/// player's canvas tube, within `pourLimit` pours.
struct PaintLevel {
    let index: Int             // 0-based
    let target: [Int]          // color ids, bottom -> top
    let supplyColors: [Int]    // unique color ids, one supply tube each
    let par: Int               // pours for 3 stars (== target.count)
    let pourLimit: Int         // hard cap; grows by +2 per reward/booster
}

// MARK: - Rules (single source of truth)

/// A pour is legal while the canvas has room and pours remain.
func legalCanvasPour(canvas: [Int], poursUsed: Int, pourLimit: Int) -> Bool {
    canvas.count < canvasCapacity && poursUsed < pourLimit
}

func applyCanvasPour(canvas: inout [Int], color: Int) {
    canvas.append(color)
}

func canvasMatches(_ canvas: [Int], target: [Int]) -> Bool {
    canvas == target
}

/// Length of the correct prefix: how many bottom bands already match the
/// target. Used by the "reveal next band" hint.
func correctPrefixLength(canvas: [Int], target: [Int]) -> Int {
    var n = 0
    for (a, b) in zip(canvas, target) {
        if a == b { n += 1 } else { break }
    }
    return n
}
