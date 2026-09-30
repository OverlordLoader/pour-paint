import SwiftUI

enum Route: Hashable {
    case levels
    case game(Int)
}

struct ContentView: View {
    @State private var path: [Route] = []
    @ObservedObject private var progress = ProgressStore.shared
    @State private var showHowTo = false
    @State private var showSettings = false
    @State private var soundOn = ProgressStore.shared.soundEnabled

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2B1B4D), Color(hex: 0x17102E)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    TitleArtView()
                    Text("Pour Paint")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Study the target. Pour the masterpiece.")
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button {
                        SoundManager.shared.play(.click)
                        Haptics.tap()
                        path.append(.levels)
                    } label: {
                        Text("Play")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: 0x2B1B4D))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: 0xFFD60A))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 40)
                    HStack(spacing: 28) {
                        Button("How to play") {
                            SoundManager.shared.play(.click)
                            showHowTo = true
                        }
                        .foregroundColor(.white.opacity(0.85))
                        Button {
                            toggleSound()
                        } label: {
                            Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Button {
                            SoundManager.shared.play(.click)
                            Haptics.tap()
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(progress.totalStars) stars collected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .levels:
                    LevelSelectView()
                case .game(let i):
                    GameView(levelIndex: i,
                             onNext: i + 1 < PaintLevelGenerator.totalLevels
                                ? { path.append(.game(i + 1)) } : nil)
                }
            }
            .sheet(isPresented: $showHowTo) { howToSheet }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .tint(Color(hex: 0xFFD60A))
        .onAppear {
            soundOn = ProgressStore.shared.soundEnabled
            SoundManager.shared.enabled = soundOn
        }
    }

    private func toggleSound() {
        soundOn.toggle()
        ProgressStore.shared.soundEnabled = soundOn
        SoundManager.shared.enabled = soundOn
        if soundOn { SoundManager.shared.play(.click) }
        Haptics.tap()
    }

    private var howToSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                howToRow(number: "1",
                         title: "Study the target artwork",
                         detail: "Your canvas must match its color bands exactly, bottom to top.")
                howToRow(number: "2",
                         title: "Tap a paint tube to pour",
                         detail: "Each tap adds one band of that color. Pours are limited — plan ahead!")
                howToRow(number: "3",
                         title: "Undo is free, hints cost a star",
                         detail: "Match the target within par pours for 3 stars. No timers, no failing — undo anytime.")
                Spacer()
            }
            .padding()
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHowTo = false }
                }
            }
        }
    }

    private func howToRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.title2.bold())
                .foregroundColor(Color(hex: 0x2B1B4D))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0xFFD60A))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

/// Decorative title art: a target tube next to a canvas tube mid-pour.
struct TitleArtView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 26) {
            miniTube(colors: [2, 5, 0], label: "TARGET")
            miniTube(colors: [2, 5], label: "YOU")
                .offset(y: -10)
        }
    }

    private func miniTube(colors: [Int], label: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.6))
            VStack(spacing: 3) {
                ForEach(colors.reversed(), id: \.self) { c in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.color(id: c).swiftUIColor)
                        .frame(width: 52, height: 24)
                }
                // Empty band slots, hinting at the puzzle.
                ForEach(0..<(3 - colors.count), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 24)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.5), lineWidth: 4)
            )
        }
    }
}
