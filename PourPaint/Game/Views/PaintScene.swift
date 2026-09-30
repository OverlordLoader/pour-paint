import SpriteKit
import UIKit

/// SpriteKit playfield: target artwork tube, the player's canvas tube, and
/// the supply rack. The PaintEngine owns rules and state; this scene owns
/// the juice.
final class PaintScene: SKScene {
    private weak var engine: PaintEngine?
    private var targetNode: TubeNode!
    private var canvasNode: TubeNode!
    private var supplyNodes: [TubeNode] = []
    private var visualCanvas: [Int] = []
    private var eventQueue: [PaintEvent] = []
    private var animating = false
    private let palette = Palette.all

    init(size: CGSize, engine: PaintEngine) {
        self.engine = engine
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        buildBackground()
        buildBoard()
        if let engine {
            visualCanvas = engine.canvas
            renderAll()
        }
        startAmbientBubbles()
    }

    // MARK: - Background

    private func buildBackground() {
        let tex = NodeTextures.verticalGradient(top: UIColor(hex: 0x2B1B4D),
                                                bottom: UIColor(hex: 0x17102E))
        let bg = SKSpriteNode(texture: tex, size: CGSize(width: size.width, height: size.height + 2))
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -10
        addChild(bg)

        let glows: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (0.20, 0.78, 150, 0xFF5FD2),
            (0.85, 0.38, 170, 0x3AB6FF),
            (0.68, 0.88, 120, 0xA259FF),
        ]
        for (fx, fy, r, hex) in glows {
            let g = SKSpriteNode(texture: NodeTextures.glow, color: UIColor(hex: hex),
                                 size: CGSize(width: r * 2, height: r * 2))
            g.colorBlendFactor = 1
            g.alpha = 0.14
            g.position = CGPoint(x: size.width * fx, y: size.height * fy)
            g.zPosition = -9
            addChild(g)
        }
    }

    private func startAmbientBubbles() {
        for _ in 0..<10 {
            let b = SKSpriteNode(texture: NodeTextures.softCircle, color: .white,
                                 size: CGSize(width: 26, height: 26))
            b.colorBlendFactor = 1
            b.alpha = 0.10
            b.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
            b.zPosition = -8
            addChild(b)
            let drift = SKAction.sequence([
                .moveBy(x: CGFloat.random(in: -40...40),
                        y: CGFloat.random(in: 60...140),
                        duration: Double.random(in: 6...10)),
                .fadeAlpha(to: 0, duration: 1.0),
                .run { [weak b, weak self] in
                    b?.position = CGPoint(x: CGFloat.random(in: 0...(self?.size.width ?? 300)), y: -30)
                    b?.alpha = 0.10
                },
            ])
            b.run(.repeatForever(drift))
        }
    }

    // MARK: - Board layout

    private func buildBoard() {
        guard let engine else { return }
        // Scale the whole board down on short screens (e.g. iPhone SE)
        // so the canvas tube, labels, and supply rack never overlap.
        let k = min(1.0, size.height / 800.0)

        // Supply rack along the bottom: one full tube per color.
        let n = engine.level.supplyColors.count
        let spacing: CGFloat = 10
        var w: CGFloat = 58 * k
        let maxW = size.width - 32
        let rowW = CGFloat(n) * w + CGFloat(max(0, n - 1)) * spacing
        if rowW > maxW {
            w = (maxW - CGFloat(max(0, n - 1)) * spacing) / CGFloat(n)
        }
        let sSegH: CGFloat = 26 * k
        let supplyTubeH = sSegH * 4 + 30 * k
        let supplyY: CGFloat = 170 * k + 20
        let totalW = CGFloat(n) * w + CGFloat(max(0, n - 1)) * spacing
        var x = size.width / 2 - totalW / 2 + w / 2
        for i in 0..<n {
            let node = TubeNode(index: i, tubeW: w, segH: sSegH, capacity: 4)
            node.homePosition = CGPoint(x: x, y: supplyY)
            addChild(node)
            supplyNodes.append(node)
            x += w + spacing
        }
        addLabel("PAINT SUPPLY — TAP TO POUR",
                 at: CGPoint(x: size.width / 2, y: supplyY - 28 * k))

        // Canvas + target tubes sit above the supply rack.
        let baseY = supplyY + supplyTubeH + 24 * k

        // Target artwork tube (left, smaller, not tappable).
        targetNode = TubeNode(index: -1, tubeW: 62, segH: 38 * k, capacity: canvasCapacity)
        targetNode.homePosition = CGPoint(x: size.width * 0.27, y: baseY)
        addChild(targetNode)
        addLabel("TARGET", above: targetNode)

        // Player canvas tube (right, larger).
        canvasNode = TubeNode(index: -2, tubeW: 86, segH: 48 * k, capacity: canvasCapacity)
        canvasNode.homePosition = CGPoint(x: size.width * 0.71, y: baseY)
        addChild(canvasNode)
        addLabel("YOUR CANVAS", above: canvasNode)
    }

    private func addLabel(_ text: String, above node: TubeNode) {
        addLabel(text, at: CGPoint(x: node.position.x, y: node.position.y + node.tubeH + 26))
    }

    private func addLabel(_ text: String, at pos: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 14
        label.fontColor = UIColor(white: 1, alpha: 0.65)
        label.position = pos
        label.zPosition = 30
        addChild(label)
    }

    private func renderAll() {
        guard let engine else { return }
        targetNode.render(engine.level.target, palette: palette)
        canvasNode.render(visualCanvas, palette: palette)
        for (i, node) in supplyNodes.enumerated() {
            let color = engine.level.supplyColors[i]
            node.render(Array(repeating: color, count: 4), palette: palette)
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let touch = touches.first else { return }
        let p = touch.location(in: self)
        var node: SKNode? = atPoint(p)
        while let n = node, !(n is TubeNode) { node = n.parent }
        if let tube = node as? TubeNode, tube.index >= 0 {
            engine.tapSupply(tube.index)
        }
    }

    // MARK: - Event queue

    /// Serializes animations so pour -> win always play in order.
    func handle(_ event: PaintEvent) {
        eventQueue.append(event)
        pump()
    }

    private func pump() {
        guard !animating, let event = eventQueue.first else { return }
        eventQueue.removeFirst()
        animating = true
        switch event {
        case .poured(let supplyIndex, let color):
            animatePour(supplyIndex: supplyIndex, color: color) { self.done() }
        case .illegal:
            animateIllegal { self.done() }
        case .stateRestored:
            if let engine { visualCanvas = engine.canvas }
            renderAll()
            done()
        case .hintRevealed(let color):
            animateHint(color: color) { self.done() }
        case .levelWon(let stars):
            animateWin(stars: stars) { self.done() }
        }
    }

    private func done() {
        animating = false
        if eventQueue.isEmpty {
            engine?.setBusy(false)
        } else {
            pump()
        }
    }

    // MARK: - Animations

    private func animatePour(supplyIndex: Int, color: Int, completion: @escaping () -> Void) {
        guard supplyIndex < supplyNodes.count,
              let engine else { completion(); return }
        let fromNode = supplyNodes[supplyIndex]
        let colorSK = palette[color % palette.count].skColor

        // The supply tube is bottomless: it tips, streams, and stays full.
        let start = fromNode.convert(CGPoint(x: 0, y: fromNode.tubeH + 6), to: self)
        let end = canvasNode.convert(CGPoint(x: 0, y: canvasNode.tubeH + 6), to: self)
        fromNode.tilt(angle: end.x > start.x ? -0.35 : 0.35)
        SoundManager.shared.play(.pour)
        Haptics.pour()

        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (start.x + end.x) / 2,
                                           y: max(start.y, end.y) + 70))
        for k in 0..<3 {
            let blob = SKSpriteNode(texture: NodeTextures.softCircle, color: colorSK,
                                    size: CGSize(width: 20, height: 20))
            blob.colorBlendFactor = 1
            blob.position = start
            blob.zPosition = 20
            addChild(blob)
            let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.36)
            follow.timingMode = .easeIn
            blob.run(.sequence([
                .wait(forDuration: 0.16 + Double(k) * 0.07),
                follow,
                .removeFromParent(),
            ]))
        }

        let arrive = SKAction.sequence([
            .wait(forDuration: 0.16 + 0.36 + 0.14),
            .run { [weak self] in
                guard let self else { return }
                self.visualCanvas = engine.canvas
                self.canvasNode.render(self.visualCanvas, palette: self.palette)
                self.canvasNode.popTop()
                self.burst(at: end, colors: [colorSK, .white], count: 14,
                           speed: 160, lifetime: 0.45, scale: 0.35)
                SoundManager.shared.play(.pop)
            },
            .wait(forDuration: 0.22),
            .run { fromNode.untilt() },
            .wait(forDuration: 0.18),
        ])
        run(arrive, completion: completion)
    }

    private func animateIllegal(completion: @escaping () -> Void) {
        SoundManager.shared.play(.error)
        Haptics.error()
        canvasNode.shake()
        run(.wait(forDuration: 0.32), completion: completion)
    }

    private func animateHint(color: Int, completion: @escaping () -> Void) {
        guard let engine else { completion(); return }
        if let i = engine.level.supplyColors.firstIndex(of: color),
           i < supplyNodes.count {
            supplyNodes[i].flash()
        }
        run(.wait(forDuration: 0.6), completion: completion)
    }

    private func animateWin(stars: Int, completion: @escaping () -> Void) {
        SoundManager.shared.play(.win)
        Haptics.win()
        let e = SKEmitterNode()
        e.particleTexture = NodeTextures.softCircle
        e.numParticlesToEmit = 160
        e.particleBirthRate = 90
        e.particleLifetime = 2.6
        e.particleLifetimeRange = 0.8
        e.particlePositionRange = CGVector(dx: size.width, dy: 10)
        e.position = CGPoint(x: size.width / 2, y: size.height + 20)
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.35
        e.particleSpeed = 240
        e.particleSpeedRange = 120
        e.yAcceleration = -260
        e.particleScale = 0.45
        e.particleScaleRange = 0.25
        e.particleAlpha = 1
        e.particleAlphaSpeed = -0.25
        e.particleRotationSpeed = 3
        e.particleRotationRange = 6
        let colors = palette.map { $0.skColor }
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: colors,
            times: colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) })
        e.zPosition = 60
        addChild(e)
        run(.sequence([
            .wait(forDuration: 2.4),
            .run { e.removeFromParent() },
        ]), completion: { [weak self] in
            self?.engine?.celebrationFinished()
            completion()
        })
    }

    // MARK: - Particles

    private func burst(at pos: CGPoint, colors: [SKColor], count: Int,
                       speed: CGFloat, lifetime: CGFloat, scale: CGFloat) {
        let e = SKEmitterNode()
        e.particleTexture = NodeTextures.softCircle
        e.numParticlesToEmit = count
        e.particleBirthRate = CGFloat(count) / 0.15
        e.particleLifetime = lifetime
        e.particleLifetimeRange = lifetime * 0.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.6
        e.emissionAngleRange = .pi * 2
        e.particleScale = scale
        e.particleScaleRange = scale * 0.5
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.2
        if colors.count == 1 {
            e.particleColor = colors[0]
        } else {
            e.particleColorSequence = SKKeyframeSequence(
                keyframeValues: colors,
                times: colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) })
        }
        e.particleBlendMode = .add
        e.position = pos
        e.zPosition = 50
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
    }
}
