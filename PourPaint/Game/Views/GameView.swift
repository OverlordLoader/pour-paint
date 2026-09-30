import SwiftUI
import SpriteKit

struct GameView: View {
    let levelIndex: Int
    let onNext: (() -> Void)?

    @StateObject private var engine: PaintEngine
    @State private var scene: PaintScene?
    @State private var soundOn: Bool
    @State private var showSettings = false
    @State private var showOutOfPours = false
    @State private var showHintOffer = false
    @State private var showExtraPoursOffer = false
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    init(levelIndex: Int, onNext: (() -> Void)? = nil) {
        self.levelIndex = levelIndex
        self.onNext = onNext
        _engine = StateObject(wrappedValue: PaintEngine(levelIndex: levelIndex))
        _soundOn = State(initialValue: ProgressStore.shared.soundEnabled)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: 0x17102E).ignoresSafeArea()
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    hud
                    Spacer(minLength: 0)
                    bottomBar
                }
                if engine.showWinOverlay {
                    winOverlay
                }
            }
            .onAppear {
                SoundManager.shared.enabled = soundOn
                if scene == nil {
                    let s = PaintScene(size: geo.size, engine: engine)
                    s.scaleMode = .resizeFill
                    engine.onEvent = { [weak s] event in s?.handle(event) }
                    scene = s
                }
            }
            .onChange(of: engine.won) { _, won in
                if won { AdsManager.shared.recordLevelCompleted() }
            }
            .onChange(of: engine.outOfPours) { _, out in
                if out { showOutOfPours = true }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("Out of Pours", isPresented: $showOutOfPours) {
                Button("Watch Ad (+2 Pours)") {
                    AdsManager.shared.showRewarded { earned in
                        if earned { engine.addPours(2) }
                    }
                }
                if store.extraPoursCount > 0 {
                    Button("Use Extra Pours (\(store.extraPoursCount))") {
                        if store.consumeExtraPours() { engine.addPours(2) }
                    }
                } else {
                    Button("Get More") { showSettings = true }
                }
                Button("Restart Level") { engine.restart() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You're out of pours. Watch a short ad for +2 pours, or use an Extra Pours refill.")
            }
            .alert("Reveal Next Band?", isPresented: $showHintOffer) {
                Button("Watch Ad") {
                    AdsManager.shared.showRewarded { _ in
                        // Graceful offline: the hint still reveals if no ad
                        // was available, and it always counts against stars.
                        _ = engine.revealHint()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Watch a short ad to reveal the next band you should pour. Using a hint caps this level at 1 star.")
            }
            .alert("No Extra Pours", isPresented: $showExtraPoursOffer) {
                Button("Watch Ad (+2 Pours)") {
                    AdsManager.shared.showRewarded { earned in
                        if earned { engine.addPours(2) }
                    }
                }
                Button("Get More") { showSettings = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Watch a short ad for +2 free pours, or grab a 10-pack in Settings.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Button {
                SoundManager.shared.play(.click)
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Level \(engine.levelNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(engine.poursLeft) pours left · Par \(engine.par)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button {
                SoundManager.shared.play(.click)
                Haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom controls

    private var bottomBar: some View {
        HStack(spacing: 12) {
            controlButton(icon: "arrow.uturn.backward", label: "Undo",
                          disabled: !engine.canUndo) { engine.undo() }
            controlButton(icon: "lightbulb.fill", label: "Hint",
                          disabled: engine.busy || engine.won) { showHintOffer = true }
            extraPoursButton
            controlButton(icon: "arrow.counterclockwise", label: "Restart",
                          disabled: engine.busy || engine.won) { engine.restart() }
        }
        .padding(.bottom, 30)
    }

    /// Extra Pours booster: uses an owned refill (+2 pours), or offers a
    /// rewarded ad / the store when empty. Never a dead button.
    private var extraPoursButton: some View {
        let disabled = engine.busy || engine.won
        return Button {
            SoundManager.shared.play(.click)
            Haptics.tap()
            if store.consumeExtraPours() {
                engine.addPours(StoreManager.poursPerRefill)
            } else {
                showExtraPoursOffer = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill").font(.title2.bold())
                    Text("+2 Pours").font(.caption.bold())
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 64)
                .background(Color.white.opacity(disabled ? 0.06 : 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .opacity(disabled ? 0.45 : 1)
                if store.extraPoursCount > 0 {
                    Text("\(store.extraPoursCount)")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: 0x2B1B4D))
                        .padding(6)
                        .background(Color(hex: 0xFFD60A))
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .disabled(disabled)
    }

    private func controlButton(icon: String, label: String, disabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2.bold())
                Text(label).font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 64)
            .background(Color.white.opacity(disabled ? 0.06 : 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .opacity(disabled ? 0.45 : 1)
        }
        .disabled(disabled)
    }

    // MARK: - Win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Masterpiece!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < engine.lastStars ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                    }
                }
                Text("Pours: \(engine.poursUsed) · Par: \(engine.par)")
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 12) {
                    Button("Replay") { engine.restart() }
                        .buttonStyle(WinButtonStyle())
                    if onNext != nil {
                        Button("Next") {
                            SoundManager.shared.play(.click)
                            AdsManager.shared.showInterstitialIfDue { onNext?() }
                        }
                        .buttonStyle(WinButtonStyle(primary: true))
                    }
                    Button("Levels") {
                        SoundManager.shared.play(.click)
                        AdsManager.shared.showInterstitialIfDue { dismiss() }
                    }
                    .buttonStyle(WinButtonStyle())
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x2B1B4D)))
            .padding(.horizontal, 40)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

struct WinButtonStyle: ButtonStyle {
    var primary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(primary ? Color(hex: 0xFF8A00) : Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
