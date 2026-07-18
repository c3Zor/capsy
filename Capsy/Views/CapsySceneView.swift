import SwiftUI
import SceneKit
import UIKit
import simd

// MARK: - SwiftUI wrapper

/// Capsy the character IS the vessel: a real-3D glass body (bucket, potion
/// or glass) with matte clay-coral liquid inside, a face that reacts to the
/// stress level, warm studio lighting and one hard cartoon shadow — the
/// design-book world, in SceneKit.
struct CapsySceneView: UIViewRepresentable {
    /// Target fill level 0…1. The liquid eases toward it.
    var fraction: Double
    /// Increment to drop a pebble of stress into the vessel.
    var dropSignal: Int = 0
    /// Body shape, shared with the rest of the app.
    var style: VesselStyle = .kibiras
    /// Force a mood (e.g. relief at ritual end); nil = derived from fraction.
    var mood: MascotMood? = nil
    /// Ritual phase: 0 idle · 1 inhale (O mouth, eyes closed) · 2 exhale
    /// (relaxed smile, voxel steam evaporates upward).
    var breathPhase: Int = 0
    /// Equipped hat reward id ("", "hat.leaf", "hat.beanie", "hat.crown").
    var hat: String = ""

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.scene = context.coordinator.capsy.scene
        view.pointOfView = context.coordinator.capsy.cameraNode
        view.delegate = context.coordinator
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        // The scene never needs touches — without this it swallows drag
        // gestures and the surrounding ScrollView cannot scroll.
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let capsy = context.coordinator.capsy
        capsy.targetFill = fraction
        capsy.set(style: style)
        capsy.set(mood: mood ?? MascotMood.forFraction(fraction))
        capsy.set(breathPhase: breathPhase)
        capsy.set(hat: hat)
        if dropSignal != context.coordinator.lastDropSignal {
            context.coordinator.lastDropSignal = dropSignal
            capsy.dropPebble()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let capsy = CapsyScene()
        var lastDropSignal = 0

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            capsy.step(time: time, tilt: MotionManager.shared.roll)
        }
    }
}

// MARK: - The scene

final class CapsyScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    // Set from SwiftUI; consumed on the render loop.
    var targetFill: Double = 0
    private var breathValue = 0.0   // 0 exhaled … 1 inhaled, eased on the scene clock

    private let bodyRoot = SCNNode()      // breathes (uniform scale)
    private let glassNode = SCNNode()
    private let liquidPivot = SCNNode()   // sloshes (z rotation)
    private let liquidRoot = SCNNode()    // the voxel cubes live here
    private var topCubes: [(node: SCNNode, baseY: Float, phase: Float)] = []
    private let cubeSize: Float = 0.16
    private let faceNode = SCNNode()
    private let leftEye = SCNNode()
    private let rightEye = SCNNode()
    private let mouthNode = SCNNode()
    private let shadowNode = SCNNode()

    private var style: VesselStyle = .kibiras
    private var mood: MascotMood = .ramus

    private var fill = 0.0                // eased fill
    private var builtLayers = -1          // cube layers the liquid was built with
    private var angle = 0.0, angleVel = 0.0, pendingImpulse = 0.0
    private var lastTime: TimeInterval?
    private var nextBlink: TimeInterval = 2.5
    private var breathPhase = 0
    private var lastVapor: TimeInterval = 0
    private var hatId = ""
    private let hatNode = SCNNode()

    private let liquidMaterial = SCNMaterial()

    init() {
        buildLights()
        buildCamera()
        buildShadow()
        buildBody()
        buildFace()
        scene.rootNode.addChildNode(bodyRoot)
        rebuild(for: style)
    }

    // MARK: Studio setup (design book: warm key, soft fill, ambient)

    private func buildLights() {
        func light(_ type: SCNLight.LightType, _ color: UIColor, _ intensity: CGFloat,
                   euler: SCNVector3 = SCNVector3Zero) -> SCNNode {
            let l = SCNLight()
            l.type = type
            l.color = color
            l.intensity = intensity
            let n = SCNNode()
            n.light = l
            n.eulerAngles = euler
            scene.rootNode.addChildNode(n)
            return n
        }
        _ = light(.directional, UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1), 1000,
                  euler: SCNVector3(-0.9, 0.55, 0))
        _ = light(.directional, UIColor(red: 1.0, green: 0.85, blue: 0.72, alpha: 1), 300,
                  euler: SCNVector3(-0.4, -2.4, 0))
        _ = light(.ambient, UIColor(white: 1, alpha: 1), 420)
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 38 // vertical — wide enough that the vessel never crops
        cameraNode.camera = camera
        // Slightly above the rim so the liquid's voxel surface is visible.
        cameraNode.position = SCNVector3(0, 2.1, 5.6)
        let target = SCNNode()
        target.position = SCNVector3(0, 0.72, 0)
        scene.rootNode.addChildNode(target)
        let look = SCNLookAtConstraint(target: target)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        scene.rootNode.addChildNode(cameraNode)
    }

    /// One hard flat cartoon shadow — the only playful material in the world.
    private func buildShadow() {
        let plane = SCNPlane(width: 2.1, height: 0.85)
        plane.cornerRadius = 0.42
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 0.16)
        m.isDoubleSided = true
        plane.materials = [m]
        shadowNode.geometry = plane
        shadowNode.eulerAngles.x = -.pi / 2
        shadowNode.position = SCNVector3(0, 0.005, 0)
        scene.rootNode.addChildNode(shadowNode)
    }

    private func buildBody() {
        // Truly see-through glass. Material-level transparency proved
        // unreliable here, so opacity lives on the NODE — SceneKit composites
        // node opacity dependably, and the voxel liquid always shows through.
        let glass = SCNMaterial()
        glass.lightingModel = .blinn
        glass.diffuse.contents = UIColor(red: 0.97, green: 0.94, blue: 0.90, alpha: 1)
        glass.specular.contents = UIColor(white: 1, alpha: 1)
        glass.shininess = 40
        glass.isDoubleSided = true
        glass.writesToDepthBuffer = false  // never hide what's inside
        glassNode.opacity = 0.22           // the reliable transparency switch
        glassNode.renderingOrder = 10      // draw after the liquid
        glassMaterialHolder = glass

        liquidMaterial.lightingModel = .physicallyBased
        liquidMaterial.diffuse.contents = UIColor(red: 0.91, green: 0.53, blue: 0.36, alpha: 1) // #E8865C
        liquidMaterial.roughness.contents = 0.8   // matte clay
        liquidMaterial.metalness.contents = 0.0

        liquidPivot.addChildNode(liquidRoot)
        bodyRoot.addChildNode(liquidPivot)
        bodyRoot.addChildNode(glassNode)
    }

    private var glassMaterialHolder = SCNMaterial()

    private func buildFace() {
        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = UIColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 1) // #2B2620
        dark.roughness.contents = 0.6

        for eye in [leftEye, rightEye] {
            let box = SCNBox(width: 0.10, height: 0.13, length: 0.05, chamferRadius: 0.03)
            box.materials = [dark]
            eye.geometry = box
            faceNode.addChildNode(eye)
        }
        leftEye.position = SCNVector3(-0.17, 0.10, 0)
        rightEye.position = SCNVector3(0.17, 0.10, 0)

        mouthNode.geometry = mouthGeometry(for: .ramus)
        mouthNode.position = SCNVector3(0, -0.10, 0)
        faceNode.addChildNode(mouthNode)

        bodyRoot.addChildNode(faceNode)
    }

    // MARK: Body shapes (lathe profiles: x = radius, y = height)

    private func profile(for style: VesselStyle) -> [SIMD2<Float>] {
        switch style {
        case .kibiras:
            [[0.001, 0.0], [0.60, 0.0], [0.65, 0.05], [0.78, 1.44], [0.83, 1.48], [0.83, 1.58], [0.79, 1.60]]
                .map { SIMD2($0[0], $0[1]) }
        case .eliksyras:
            [[0.001, 0.0], [0.46, 0.02], [0.72, 0.40], [0.75, 0.70], [0.62, 1.05], [0.35, 1.42], [0.15, 1.72], [0.05, 1.92]]
                .map { SIMD2($0[0], $0[1]) }
        case .taure:
            // A real goblet: foot, slim stem, then the bowl.
            [[0.001, 0.0], [0.40, 0.0], [0.42, 0.04], [0.12, 0.10], [0.06, 0.16],
             [0.06, 0.50], [0.18, 0.62], [0.44, 0.74], [0.56, 0.98], [0.59, 1.26], [0.57, 1.52]]
                .map { SIMD2($0[0], $0[1]) }
        }
    }

    private func maxLiquidHeight(for style: VesselStyle) -> Float {
        switch style {
        case .kibiras: 1.38
        case .eliksyras: 1.35
        case .taure: 1.42
        }
    }

    /// Where the liquid starts: the goblet's bowl begins above the stem.
    private func liquidFloor(for style: VesselStyle) -> Float {
        style == .taure ? 0.68 : 0.02
    }

    /// Liquid surface height for a given fill, in profile coordinates.
    private func surfaceHeight(_ fill: Double, style: VesselStyle) -> Float {
        let floor = liquidFloor(for: style)
        return floor + Float(fill) * (maxLiquidHeight(for: style) - floor)
    }

    /// High enough that the face stays dry at everyday levels — it only
    /// goes under when the vessel is nearly full, which is the point.
    private func faceAnchor(for style: VesselStyle) -> SCNVector3 {
        switch style {
        case .kibiras:  SCNVector3(0, 1.10, 0.80)
        case .eliksyras: SCNVector3(0, 0.88, 0.70)
        case .taure:    SCNVector3(0, 1.08, 0.60)
        }
    }

    private func radius(atHeight y: Float, of profile: [SIMD2<Float>]) -> Float {
        for i in 1..<profile.count where profile[i].y >= y {
            let a = profile[i - 1], b = profile[i]
            let t = b.y == a.y ? 0 : (y - a.y) / (b.y - a.y)
            return a.x + (b.x - a.x) * t
        }
        return profile.last?.x ?? 0
    }

    /// Revolves a 2D profile around the Y axis into a triangle mesh.
    private func lathe(_ profile: [SIMD2<Float>], segments: Int = 48) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        for (i, p) in profile.enumerated() {
            let prev = profile[max(i - 1, 0)]
            let next = profile[min(i + 1, profile.count - 1)]
            let dy = next.y - prev.y
            let dr = next.x - prev.x
            for s in 0...segments {
                let a = Float(s) / Float(segments) * 2 * .pi
                vertices.append(SCNVector3(p.x * cos(a), p.y, p.x * sin(a)))
                var n = SIMD3<Float>(dy * cos(a), -dr, dy * sin(a))
                if simd_length(n) < 1e-6 { n = SIMD3<Float>(0, 1, 0) }
                n = simd_normalize(n)
                normals.append(SCNVector3(n.x, n.y, n.z))
            }
        }
        let cols = Int32(segments + 1)
        for i in 0..<Int32(profile.count - 1) {
            for s in 0..<Int32(segments) {
                let a = i * cols + s
                let b = a + 1
                let c = (i + 1) * cols + s
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        return geometry
    }

    // MARK: Rebuilds

    func set(style newStyle: VesselStyle) {
        guard newStyle != style else { return }
        style = newStyle
        rebuild(for: style)
    }

    private let rimNode = SCNNode()

    private func rebuild(for style: VesselStyle) {
        let geometry = lathe(profile(for: style))
        geometry.materials = [glassMaterialHolder]
        glassNode.geometry = geometry
        faceNode.position = faceAnchor(for: style)

        // An ink ring at the opening defines the vessel even where the
        // glass is nearly invisible — the 3D echo of the 2D outline.
        let top = profile(for: style).last ?? SIMD2(0.7, 1.6)
        let torus = SCNTorus(ringRadius: CGFloat(top.x), pipeRadius: 0.022)
        let ink = SCNMaterial()
        ink.lightingModel = .constant
        ink.diffuse.contents = UIColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 0.45)
        torus.materials = [ink]
        rimNode.geometry = torus
        rimNode.position = SCNVector3(0, top.y, 0)
        if rimNode.parent == nil { bodyRoot.addChildNode(rimNode) }

        // Re-seat the hat on the new body shape.
        let currentHat = hatId
        hatId = "~"
        set(hat: currentHat)

        builtLayers = -1 // force liquid rebuild
    }

    /// The liquid is a stack of little clay cubes — the voxel soul of the
    /// design book, in real 3D. The top layer bobs so the water never freezes.
    private func rebuildLiquid() {
        let floor = liquidFloor(for: style)
        let surfaceY = surfaceHeight(fill, style: style)
        builtLayers = Int((surfaceY - floor) / cubeSize)
        liquidRoot.childNodes.forEach { $0.removeFromParentNode() }
        topCubes.removeAll()
        guard fill > 0.02 else { return }

        let body = profile(for: style)
        let box = SCNBox(width: CGFloat(cubeSize) * 0.94,
                         height: CGFloat(cubeSize) * 0.94,
                         length: CGFloat(cubeSize) * 0.94,
                         chamferRadius: CGFloat(cubeSize) * 0.16)
        box.materials = [liquidMaterial]

        var y = floor + cubeSize / 2
        while y < surfaceY {
            let isTopLayer = y + cubeSize >= surfaceY
            let r = radius(atHeight: y, of: body) * 0.82
            var x = -r
            while x <= r {
                var z = -r
                while z <= r {
                    if (x * x + z * z).squareRoot() + cubeSize * 0.35 <= r {
                        let cube = SCNNode(geometry: box)
                        cube.position = SCNVector3(x, y, z)
                        liquidRoot.addChildNode(cube)
                        if isTopLayer {
                            topCubes.append((cube, y, Float.random(in: 0...(2 * .pi))))
                        }
                    }
                    z += cubeSize
                }
                x += cubeSize
            }
            y += cubeSize
        }

        // Slosh around the middle of the liquid mass.
        let mid = (floor + surfaceY) * 0.5
        liquidPivot.position = SCNVector3(0, mid, 0)
        liquidRoot.position = SCNVector3(0, -mid, 0)
    }

    // MARK: Mood & face

    func set(mood newMood: MascotMood) {
        guard newMood != mood else { return }
        mood = newMood
        applyFace()
    }

    func set(breathPhase newPhase: Int) {
        guard newPhase != breathPhase else { return }
        breathPhase = newPhase
        applyFace()
        // The water feels every turn of the breath — a soft push each way.
        pendingImpulse += newPhase == 1 ? 0.10 : (newPhase == 2 ? -0.10 : 0)
    }

    /// The face is the instruction: during the ritual Capsy closes his eyes,
    /// makes an "O" on the inhale and a relaxed smile on the exhale —
    /// you breathe with him.
    private func applyFace() {
        switch breathPhase {
        case 1:
            mouthNode.geometry = mouthOGeometry()
            setEyes(scaleY: 0.22)
        case 2:
            mouthNode.geometry = mouthGeometry(for: .palengvejas)
            setEyes(scaleY: 0.22)
        default:
            mouthNode.geometry = mouthGeometry(for: mood)
            setEyes(scaleY: mood == .sunkus ? 0.72 : (mood == .palengvejas ? 0.32 : 1.0))
        }
    }

    private func setEyes(scaleY: Float) {
        for eye in [leftEye, rightEye] {
            eye.scale = SCNVector3(1, scaleY, 1)
        }
    }

    /// Small open "O" mouth — breathing in.
    private func mouthOGeometry() -> SCNGeometry {
        let path = UIBezierPath(ovalIn: CGRect(x: -0.045, y: -0.05, width: 0.09, height: 0.10))
        let shape = SCNShape(path: path, extrusionDepth: 0.03)
        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = UIColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 1)
        dark.roughness.contents = 0.6
        shape.materials = [dark]
        return shape
    }

    private func mouthGeometry(for mood: MascotMood) -> SCNGeometry {
        let width: CGFloat = 0.20
        let thickness: CGFloat = 0.030
        let curve: CGFloat = switch mood {
        case .ramus: -0.055        // small smile (down in path space = up on screen? no — SceneKit y up, negative control = smile)
        case .susimastes: 0.0      // flat
        case .sunkus: 0.055        // frown
        case .palengvejas: -0.085  // big relieved smile
        }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -width / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: 0),
                          controlPoint: CGPoint(x: 0, y: curve * 2))
        path.addLine(to: CGPoint(x: width / 2, y: thickness))
        path.addQuadCurve(to: CGPoint(x: -width / 2, y: thickness),
                          controlPoint: CGPoint(x: 0, y: curve * 2 + thickness))
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: 0.03)
        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = UIColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 1)
        dark.roughness.contents = 0.6
        shape.materials = [dark]
        return shape
    }

    // MARK: Hats (bought in the Rewards shop, worn with pride)

    func set(hat newHat: String) {
        guard newHat != hatId else { return }
        hatId = newHat
        hatNode.childNodes.forEach { $0.removeFromParentNode() }
        if hatNode.parent == nil { bodyRoot.addChildNode(hatNode) }

        let top = profile(for: style).last ?? SIMD2(0.7, 1.6)
        hatNode.position = SCNVector3(0.12, top.y + 0.02, 0)
        hatNode.eulerAngles.z = -0.12 // worn at a jaunty little angle

        func material(_ color: UIColor) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = color
            m.roughness.contents = 0.7
            return m
        }

        switch hatId {
        case "hat.leaf":
            // A single soft-green voxel leaf.
            let leaf = SCNBox(width: 0.3, height: 0.05, length: 0.18, chamferRadius: 0.02)
            leaf.materials = [material(UIColor(red: 0.55, green: 0.66, blue: 0.42, alpha: 1))]
            let stem = SCNBox(width: 0.05, height: 0.1, length: 0.05, chamferRadius: 0.01)
            stem.materials = leaf.materials
            let leafNode = SCNNode(geometry: leaf)
            leafNode.position = SCNVector3(0.06, 0.09, 0)
            leafNode.eulerAngles.z = 0.35
            let stemNode = SCNNode(geometry: stem)
            hatNode.addChildNode(stemNode)
            hatNode.addChildNode(leafNode)
        case "hat.beanie":
            // A cozy coral beanie with a little pom.
            let dome = SCNCylinder(radius: 0.30, height: 0.18)
            dome.materials = [material(UIColor(red: 0.77, green: 0.45, blue: 0.31, alpha: 1))]
            let brim = SCNCylinder(radius: 0.32, height: 0.06)
            brim.materials = [material(UIColor(red: 0.60, green: 0.34, blue: 0.23, alpha: 1))]
            let pom = SCNSphere(radius: 0.07)
            pom.materials = [material(UIColor(red: 0.93, green: 0.89, blue: 0.84, alpha: 1))]
            let domeNode = SCNNode(geometry: dome)
            domeNode.position = SCNVector3(0, 0.11, 0)
            let brimNode = SCNNode(geometry: brim)
            brimNode.position = SCNVector3(0, 0.03, 0)
            let pomNode = SCNNode(geometry: pom)
            pomNode.position = SCNVector3(0, 0.24, 0)
            hatNode.addChildNode(brimNode)
            hatNode.addChildNode(domeNode)
            hatNode.addChildNode(pomNode)
        case "hat.crown":
            // A tiny golden voxel crown.
            let gold = material(UIColor(red: 0.85, green: 0.68, blue: 0.35, alpha: 1))
            let band = SCNCylinder(radius: 0.22, height: 0.09)
            band.materials = [gold]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, 0.05, 0)
            hatNode.addChildNode(bandNode)
            for i in 0..<4 {
                let spike = SCNBox(width: 0.07, height: 0.1, length: 0.07, chamferRadius: 0.01)
                spike.materials = [gold]
                let a = Double(i) * .pi / 2
                let spikeNode = SCNNode(geometry: spike)
                spikeNode.position = SCNVector3(Float(cos(a)) * 0.18, 0.13, Float(sin(a)) * 0.18)
                hatNode.addChildNode(spikeNode)
            }
        default:
            break // no hat — a free head is also a look
        }
    }

    private func blink() {
        let close = SCNAction.scaleY(to: 0.12, duration: 0.07)
        let open = SCNAction.scaleY(to: mood == .sunkus ? 0.72 : 1.0, duration: 0.09)
        let blinkAction = SCNAction.sequence([close, open])
        leftEye.runAction(blinkAction)
        rightEye.runAction(blinkAction)
    }

    // MARK: Events

    /// A coral pebble of stress falls in from above; the liquid takes the hit.
    func dropPebble() {
        let sphere = SCNSphere(radius: 0.075)
        sphere.materials = [liquidMaterial]
        let pebble = SCNNode(geometry: sphere)
        let x = Float.random(in: -0.14...0.14)
        pebble.position = SCNVector3(x, 2.7, 0)
        bodyRoot.addChildNode(pebble)

        let surfaceY = surfaceHeight(max(fill, 0.05), style: style)
        let fall = SCNAction.move(to: SCNVector3(x, surfaceY, 0), duration: 0.34)
        fall.timingMode = .easeIn
        let sink = SCNAction.move(by: SCNVector3(0, -0.15, 0), duration: 0.12)
        pebble.runAction(.sequence([fall, sink, .removeFromParentNode()])) { [weak self] in
            guard let self else { return }
            self.pendingImpulse += x < 0 ? 0.55 : -0.55
            DispatchQueue.main.async { Haptics.splash() }
        }
    }

    // MARK: Per-frame

    func step(time: TimeInterval, tilt: Double) {
        defer { lastTime = time }
        guard let last = lastTime else { return }
        let dt = min(time - last, 1.0 / 20.0)
        guard dt > 0 else { return }

        // Liquid level eases toward its target. Cubes are rebuilt only when
        // a whole layer changes — rebuilding every frame caused visible jank.
        fill += (targetFill - fill) * min(1, dt * 3.0)
        let targetLayers = Int((surfaceHeight(fill, style: style) - liquidFloor(for: style)) / cubeSize)
        if targetLayers != builtLayers { rebuildLiquid() }

        // Damped-spring slosh: the surface chases the device tilt with inertia.
        // With no tilt (simulator, phone on a table) a slow ambient sway keeps
        // the water alive — it must never freeze.
        let ambient = abs(tilt) < 0.02 ? 0.03 * sin(time * 0.85) : 0
        let goal = max(-0.45, min(0.45, tilt)) * 0.45 + ambient
        angleVel += (26 * (goal - angle) - 3.4 * angleVel) * dt
        angleVel += pendingImpulse
        pendingImpulse = 0
        angle += angleVel * dt
        liquidPivot.eulerAngles.z = Float(angle)

        // Surface cubes bob gently — waves on top of the voxel water.
        let waveAmp = Float(0.018 + min(0.03, abs(angleVel) * 0.06))
        for cube in topCubes {
            cube.node.position.y = cube.baseY + waveAmp * sin(Float(time) * 2.4 + cube.phase)
        }

        // Ritual breathing lives on the SCENE clock. Values handed in from
        // SwiftUI jump between phases (representables get the final value
        // instantly), so the scene itself eases — a continuous curve with
        // no pop at the inhale/exhale turn. Inhale fills in ~4 s, exhale
        // empties in ~6 s.
        let breathTarget: Double = breathPhase == 1 ? 1 : 0
        let breathRate: Double = breathPhase == 1 ? 1.0 : 0.55
        breathValue += (breathTarget - breathValue) * min(1, dt * breathRate)

        // 12/min idle breath + the ritual breath on top (design book #041).
        let idle = 0.045 * sin(time * 1.257)
        let scale = Float(1 + idle + breathValue * 0.16)
        bodyRoot.scale = SCNVector3(scale, scale, scale)
        shadowNode.scale = SCNVector3(scale, scale, 1)
        // Chest lifts back a touch on the inhale — the body breathes, not
        // just inflates.
        bodyRoot.eulerAngles.x = Float(-0.05 * breathValue)

        // A full vessel trembles, asking to be poured out.
        if fill > 0.97 {
            bodyRoot.position.x = Float(sin(time * 30) * 0.015)
        } else {
            bodyRoot.position.x = 0
        }

        // Occasional blink (not while eyes are closed for the ritual).
        if time > nextBlink, mood != .palengvejas, breathPhase == 0 {
            nextBlink = time + Double.random(in: 2.4...5.0)
            blink()
        }

        // Exhale: the stress evaporates — little voxel steam cubes rise,
        // wobble and dissolve, like in a good cozy game.
        if breathPhase == 2, time - lastVapor > 0.12, fill > 0.03 {
            lastVapor = time
            spawnVapor()
        }
    }

    /// One voxel of steam: spawns at the liquid surface, floats up,
    /// spins gently, shrinks and fades away.
    private func spawnVapor() {
        let size = CGFloat(Double.random(in: 0.05...0.09))
        let box = SCNBox(width: size, height: size, length: size,
                         chamferRadius: size * 0.2)
        let steam = SCNMaterial()
        steam.lightingModel = .physicallyBased
        steam.diffuse.contents = UIColor(red: 0.95, green: 0.66, blue: 0.50, alpha: 1)
        steam.roughness.contents = 0.9
        box.materials = [steam]

        let node = SCNNode(geometry: box)
        let surfaceY = surfaceHeight(fill, style: style)
        let r = radius(atHeight: surfaceY, of: profile(for: style)) * 0.55
        node.position = SCNVector3(Float.random(in: -r...r),
                                   surfaceY + 0.06,
                                   Float.random(in: -r...r))
        node.opacity = 0.9
        bodyRoot.addChildNode(node)

        let duration = Double.random(in: 1.5...2.3)
        let rise = SCNAction.moveBy(x: CGFloat(Double.random(in: -0.3...0.3)),
                                    y: CGFloat(Double.random(in: 1.5...2.1)),
                                    z: 0, duration: duration)
        rise.timingMode = .easeOut
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat(Double.random(in: -1.6...1.6)),
                                      z: CGFloat(Double.random(in: -0.5...0.5)),
                                      duration: duration)
        let fade = SCNAction.fadeOpacity(to: 0, duration: duration)
        let shrink = SCNAction.scale(to: 0.25, duration: duration)
        node.runAction(.sequence([.group([rise, spin, fade, shrink]),
                                  .removeFromParentNode()]))
    }
}

private extension SCNAction {
    static func scaleY(to y: CGFloat, duration: TimeInterval) -> SCNAction {
        .customAction(duration: duration) { node, elapsed in
            let t = duration == 0 ? 1 : elapsed / duration
            let startY = CGFloat(node.scale.y)
            let newY = startY + (y - startY) * t
            node.scale = SCNVector3(node.scale.x, Float(newY), node.scale.z)
        }
    }
}
