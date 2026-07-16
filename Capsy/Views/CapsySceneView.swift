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
    /// 0…1 ritual breathing drive (0 = idle breathing only).
    var breath: Double = 0
    /// Force a mood (e.g. relief at ritual end); nil = derived from fraction.
    var mood: MascotMood? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.scene = context.coordinator.capsy.scene
        view.pointOfView = context.coordinator.capsy.cameraNode
        view.delegate = context.coordinator
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let capsy = context.coordinator.capsy
        capsy.targetFill = fraction
        capsy.breathDrive = breath
        capsy.set(style: style)
        capsy.set(mood: mood ?? MascotMood.forFraction(fraction))
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
    var breathDrive: Double = 0

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
    private var builtFill = -1.0          // fill the liquid mesh was built for
    private var angle = 0.0, angleVel = 0.0, pendingImpulse = 0.0
    private var lastTime: TimeInterval?
    private var nextBlink: TimeInterval = 2.5

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
        camera.fieldOfView = 30
        cameraNode.camera = camera
        // Slightly above the rim so the liquid's voxel surface is visible.
        cameraNode.position = SCNVector3(0, 2.1, 5.2)
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
            [[0.001, 0.0], [0.50, 0.0], [0.54, 0.04], [0.67, 1.50], [0.71, 1.56]]
                .map { SIMD2($0[0], $0[1]) }
        }
    }

    private func maxLiquidHeight(for style: VesselStyle) -> Float {
        style == .eliksyras ? 1.35 : 1.38
    }

    /// High enough that the face stays dry at everyday levels — it only
    /// goes under when the vessel is nearly full, which is the point.
    private func faceAnchor(for style: VesselStyle) -> SCNVector3 {
        switch style {
        case .kibiras:  SCNVector3(0, 1.10, 0.80)
        case .eliksyras: SCNVector3(0, 0.88, 0.70)
        case .taure:    SCNVector3(0, 1.06, 0.68)
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

        builtFill = -1 // force liquid rebuild
    }

    /// The liquid is a stack of little clay cubes — the voxel soul of the
    /// design book, in real 3D. The top layer bobs so the water never freezes.
    private func rebuildLiquid() {
        builtFill = fill
        liquidRoot.childNodes.forEach { $0.removeFromParentNode() }
        topCubes.removeAll()
        guard fill > 0.02 else { return }

        let body = profile(for: style)
        let surfaceY = Float(fill) * maxLiquidHeight(for: style)
        let box = SCNBox(width: CGFloat(cubeSize) * 0.94,
                         height: CGFloat(cubeSize) * 0.94,
                         length: CGFloat(cubeSize) * 0.94,
                         chamferRadius: CGFloat(cubeSize) * 0.16)
        box.materials = [liquidMaterial]

        var y = cubeSize / 2
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
        liquidPivot.position = SCNVector3(0, surfaceY * 0.5, 0)
        liquidRoot.position = SCNVector3(0, -surfaceY * 0.5, 0)
    }

    // MARK: Mood & face

    func set(mood newMood: MascotMood) {
        guard newMood != mood else { return }
        mood = newMood
        mouthNode.geometry = mouthGeometry(for: mood)
        let droop: Float = mood == .sunkus ? 0.72 : (mood == .palengvejas ? 0.32 : 1.0)
        for eye in [leftEye, rightEye] {
            eye.scale = SCNVector3(1, droop, 1)
        }
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

        let surfaceY = Float(max(fill, 0.05)) * maxLiquidHeight(for: style)
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

        // Liquid level eases toward its target; mesh rebuilds only on change.
        fill += (targetFill - fill) * min(1, dt * 3.0)
        if abs(fill - builtFill) > 0.004 { rebuildLiquid() }

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

        // Breathing: 12/min idle + ritual drive (design book #041).
        let idle = 0.045 * sin(time * 1.257)
        let scale = Float(1 + idle + breathDrive * 0.10)
        bodyRoot.scale = SCNVector3(scale, scale, scale)
        shadowNode.scale = SCNVector3(scale, scale, 1)

        // A full vessel trembles, asking to be poured out.
        if fill > 0.97 {
            bodyRoot.position.x = Float(sin(time * 30) * 0.015)
        } else {
            bodyRoot.position.x = 0
        }

        // Occasional blink.
        if time > nextBlink, mood != .palengvejas {
            nextBlink = time + Double.random(in: 2.4...5.0)
            blink()
        }
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
