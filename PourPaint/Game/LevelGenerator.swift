import Foundation

// MARK: - Deterministic RNG

/// Tiny xorshift RNG so level N is identical on every device and every launch.
/// No level storage needed; generation is cheap enough to run on demand.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
}

// MARK: - Level generator

enum PaintLevelGenerator {
    static let totalLevels = 50

    /// Difficulty ramp: more bands (3->6), bigger color pool (3->8), and the
    /// pour slack tightens (3->2->1) as levels progress.
    static func config(for index: Int) -> (bands: Int, colors: Int, slack: Int) {
        let bands: Int
        let colors: Int
        switch index {
        case 0..<10:  bands = 3; colors = 3
        case 10..<20: bands = 4; colors = 4
        case 20..<30: bands = 4; colors = 5
        case 30..<40: bands = 5; colors = 6
        default:      bands = 6; colors = 8
        }
        let slack: Int
        switch index {
        case 0..<10:  slack = 3
        case 10..<30: slack = 2
        default:      slack = 1
        }
        return (bands, colors, slack)
    }

    static func generate(index: Int) -> PaintLevel {
        var salt: UInt64 = 0
        while true {
            var rng = SeededRNG(seed: UInt64(index &+ 1) &* 0x9E3779B97F4A7C15 &+ salt &+ 0xBEEF_1234)
            if let level = attempt(index: index, rng: &rng) { return level }
            salt &+= 1
        }
    }

    /// Certified-solvable generation:
    ///  1. Generate a SOLUTION pour sequence first (random colors, never the
    ///     same color twice in a row — consecutive duplicates would be
    ///     indistinguishable bands in the tube).
    ///  2. Derive the target artwork from that solution.
    ///  3. CERTIFY: replay the solution through the real game rules
    ///     (legalCanvasPour / applyCanvasPour) and accept the level only if
    ///     every pour is legal, the canvas ends matching the target exactly,
    ///     and the pour count fits the limit. Discard and regenerate on any
    ///     failure.
    private static func attempt(index: Int, rng: inout SeededRNG) -> PaintLevel? {
        let (bands, colorCount, slack) = config(for: index)

        var solution: [Int] = []
        while solution.count < bands {
            let c = Int.random(in: 0..<colorCount, using: &rng)
            if solution.last == c { continue }
            solution.append(c)
        }
        let target = solution

        // The supply rack holds exactly the colors the target needs, shuffled
        // so tube position carries no information.
        var supply = Array(Set(target))
        supply.shuffle(using: &rng)

        let par = target.count
        let pourLimit = par + slack

        // CERTIFY through the real rules.
        var canvas: [Int] = []
        var poursUsed = 0
        for color in solution {
            guard legalCanvasPour(canvas: canvas, poursUsed: poursUsed,
                                  pourLimit: pourLimit) else { return nil }
            applyCanvasPour(canvas: &canvas, color: color)
            poursUsed += 1
        }
        guard canvasMatches(canvas, target: target) else { return nil }
        guard poursUsed == par && poursUsed <= pourLimit else { return nil }
        // Not trivial: at least two distinct colors in the artwork.
        guard Set(target).count >= 2 else { return nil }

        return PaintLevel(index: index, target: target, supplyColors: supply,
                          par: par, pourLimit: pourLimit)
    }
}
