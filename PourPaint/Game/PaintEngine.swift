import Foundation
import Combine

/// Visual events the SpriteKit scene animates. The engine owns the rules and
/// state; the scene owns the juice. Sound and haptics are triggered by the
/// scene so they stay in sync with the animation.
enum PaintEvent {
    case poured(supplyIndex: Int, color: Int)
    case illegal
    case stateRestored
    case hintRevealed(color: Int)
    case levelWon(stars: Int)
}

final class PaintEngine: ObservableObject {
    @Published private(set) var canvas: [Int] = []
    @Published private(set) var poursUsed = 0
    @Published private(set) var pourLimit: Int
    @Published private(set) var hintsUsed = 0
    @Published private(set) var usedExtraHelp = false
    @Published private(set) var busy: Bool = false
    @Published private(set) var won: Bool = false
    @Published private(set) var showWinOverlay: Bool = false
    @Published private(set) var lastStars: Int = 0

    let level: PaintLevel

    /// Wired by the view to the SpriteKit scene.
    var onEvent: ((PaintEvent) -> Void)?

    var levelIndex: Int { level.index }
    var levelNumber: Int { level.index + 1 }
    var par: Int { level.par }
    var poursLeft: Int { max(0, pourLimit - poursUsed) }
    var canUndo: Bool { !history.isEmpty && !busy && !won }
    var outOfPours: Bool { !won && poursUsed >= pourLimit && !busy }

    private var history: [(canvas: [Int], poursUsed: Int)] = []

    init(levelIndex: Int) {
        let level = PaintLevelGenerator.generate(index: levelIndex)
        self.level = level
        self.pourLimit = level.pourLimit
    }

    /// Called by the scene to lock/unlock input around animations.
    func setBusy(_ value: Bool) {
        busy = value
    }

    /// Called by the scene after the win celebration finishes.
    func celebrationFinished() {
        showWinOverlay = true
    }

    // MARK: - Input

    /// One tap on a supply tube pours a single band of its color.
    func tapSupply(_ i: Int) {
        guard !busy, !won, level.supplyColors.indices.contains(i) else { return }
        let color = level.supplyColors[i]
        guard legalCanvasPour(canvas: canvas, poursUsed: poursUsed,
                              pourLimit: pourLimit) else {
            onEvent?(.illegal)
            return
        }
        history.append((canvas, poursUsed))
        applyCanvasPour(canvas: &canvas, color: color)
        poursUsed += 1
        busy = true
        onEvent?(.poured(supplyIndex: i, color: color))
        if canvasMatches(canvas, target: level.target) {
            won = true
            lastStars = earnedStars()
            ProgressStore.shared.recordWin(level: levelIndex, stars: lastStars)
            onEvent?(.levelWon(stars: lastStars))
        }
    }

    /// Unlimited undo of the last pour. Free — it never costs stars.
    func undo() {
        guard canUndo else { return }
        let last = history.removeLast()
        canvas = last.canvas
        poursUsed = last.poursUsed
        SoundManager.shared.play(.click)
        Haptics.tap()
        onEvent?(.stateRestored)
    }

    func restart() {
        guard !busy else { return }
        canvas = []
        poursUsed = 0
        pourLimit = level.pourLimit
        hintsUsed = 0
        usedExtraHelp = false
        won = false
        showWinOverlay = false
        history = []
        SoundManager.shared.play(.click)
        Haptics.tap()
        onEvent?(.stateRestored)
    }

    // MARK: - Hint & extra pours

    /// "Reveal next band" hint: returns the color id of the first target band
    /// that is not yet correctly placed. Counts against the star rating.
    func revealHint() -> Int? {
        guard !busy, !won else { return nil }
        let p = correctPrefixLength(canvas: canvas, target: level.target)
        guard p < level.target.count else { return nil }
        hintsUsed += 1
        let color = level.target[p]
        SoundManager.shared.play(.pop)
        Haptics.select()
        onEvent?(.hintRevealed(color: color))
        return color
    }

    /// +2 pours, granted by a rewarded ad or an Extra Pours booster.
    /// Marks the run as helped, which caps the rating at 1 star.
    func addPours(_ n: Int) {
        guard !won else { return }
        pourLimit += n
        usedExtraHelp = true
        SoundManager.shared.play(.pop)
        Haptics.complete()
    }

    // MARK: - Scoring

    private func earnedStars() -> Int {
        if poursUsed <= par && hintsUsed == 0 && !usedExtraHelp { return 3 }
        if hintsUsed == 0 && !usedExtraHelp { return 2 }
        return 1
    }
}
