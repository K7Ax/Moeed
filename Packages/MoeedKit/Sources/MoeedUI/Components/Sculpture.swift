import SwiftUI
import Foundation

/// The logo as a small 3D sculpture: stairs climbing into a lit arch, a play mark floating in the doorway,
/// a ring with beads in orbit, on a glass plinth. Real geometry — a camera, Lambert light, back-face culling
/// and a painter's sort — drawn with Canvas, so it renders the same on device and in CI screenshots.
/// It sways on its own and turns when you drag it.
struct LogoSculpture: View {
    /// How many of the three steps are lit (the import screen lights one per finished stage).
    var litSteps = 3
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var drag = 0.0
    @State private var fling = 0.0
    @State private var flungAt = Date.distantPast

    var body: some View {
        Group {
            if isSnapshot {
                canvas(time: 2.4, now: .distantPast)
            } else {
                TimelineView(.animation) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000), now: timeline.date)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { drag = $0.translation.width / 150 }
                .onEnded { _ in
                    fling = drag
                    flungAt = .now
                    drag = 0
                }
        )
        .accessibilityHidden(true)
    }

    private func canvas(time: Double, now: Date) -> some View {
        // After a drag, spring back to the resting sway.
        let since = now.timeIntervalSince(flungAt)
        let settle = since < 0 || since > 4 ? 0 : fling * exp(-since * 3.2) * cos(since * 6.5)
        let scene = SculptureScene(time: time, yawOffset: drag + settle, litSteps: litSteps)
        return Canvas { context, size in
            scene.draw(in: &context, size: size)
        }
    }
}

// MARK: - Scene

struct SculptureScene {
    var time: Double
    var yawOffset: Double
    var litSteps: Int

    private enum Item {
        case face(Face)
        case sphere(Vec3, Double, RGB)
        case segment(Vec3, Vec3, RGB, Double)
        case glow(Vec3, Double, Color)
    }

    private static let light = Vec3(0.55, -0.75, 0.95).normalized
    private static let ringRadius = 3.3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 8.4, size.height / 6.9)
        let camera = Camera(
            yaw: -0.4 + 0.2 * sin(time * 0.42) + yawOffset,
            pitch: 0.36,
            scale: scale,
            origin: CGPoint(x: size.width / 2, y: size.height / 2 + 1.75 * scale)
        )

        drawFloor(in: &context, camera: camera)

        var items: [(depth: Double, item: Item)] = []
        for face in solids() where face.doubleSided || camera.toView(face.normal).y < 0 {
            items.append((face.points.map(camera.depth).average + face.bias, .face(face)))
        }
        let play = playCenter
        items.append((camera.depth(play) + 0.02, .glow(play, 1.7, Theme.mint.opacity(litSteps == 3 ? 0.55 : 0.2))))
        for (center, radius, color) in spheres() {
            items.append((camera.depth(center), .sphere(center, radius, color)))
        }
        for (a, b, color, width) in rings() {
            items.append((camera.depth(a.mid(b)), .segment(a, b, color, width)))
        }
        // The plinth's neon edge always sits on top of the plinth.
        for (a, b, color, width) in plinthEdge() {
            items.append((camera.depth(a.mid(b)) - 3, .segment(a, b, color, width)))
        }

        items.sort { $0.depth > $1.depth }
        for entry in items {
            switch entry.item {
            case let .face(face): drawFace(face, in: &context, camera: camera)
            case let .sphere(center, radius, color): drawSphere(center, radius, color, in: &context, camera: camera)
            case let .segment(a, b, color, width): drawSegment(a, b, color, width, in: &context, camera: camera)
            case let .glow(center, radius, color): drawGlow(center, radius, color, in: &context, camera: camera)
            }
        }
    }

    // MARK: Geometry

    private var bob: Double { sin(time * 1.3) * 0.12 }

    private var playCenter: Vec3 { Vec3(0.05, 0, 2.9 + bob * 0.6) }

    private func solids() -> [Face] {
        var faces: [Face] = []

        // Glass plinth.
        faces += Mesh.cylinder(radius: 3.0, z0: -0.4, z1: 0, segments: 44, material: .plinth)

        // Arch: an extruded doorway, with light inside it.
        let arch = Mesh.archOutline(outer: 2.0, inner: 1.3, spring: 3.0)
        faces += Mesh.prism(arch, y0: -0.35, y1: 0.35, material: .arch)
        var portal = Face(points: Mesh.doorway(halfWidth: 1.3, spring: 3.0).map { Vec3($0.0, 0.2, $0.1) },
                          normal: Vec3(0, -1, 0), material: .arch)
        portal.kind = .portal
        portal.doubleSided = true
        faces.append(portal)

        // Three steps climbing to the doorway.
        for k in 0..<3 {
            let y1 = -0.35 - Double(2 - k) * 0.7
            faces += Mesh.box(Vec3(-1.0, y1 - 0.7, 0), Vec3(1.0, y1, Double(k + 1) * 0.55),
                              material: k < litSteps ? .stair : .stairOff)
        }

        // The play mark, floating in the doorway.
        let c = playCenter
        let triangle = [(c.x - 0.47, c.z - 0.55), (c.x + 0.5, c.z), (c.x - 0.47, c.z + 0.55)]
        faces += Mesh.prism(triangle, y0: -0.13, y1: 0.13, material: litSteps == 3 ? .play : .stairOff)

        // A pink cube tumbling off to the side: the pen's colour, clashing with all that teal.
        let spin = time * 0.5
        faces += Mesh.box(Vec3(-0.3, -0.3, -0.3), Vec3(0.3, 0.3, 0.3), material: .pen)
            .map { $0.rotated(z: spin, x: 0.6 + spin * 0.6).moved(by: Vec3(-3.15, -0.6, 3.5 + bob)) }

        return faces
    }

    private func spheres() -> [(Vec3, Double, RGB)] {
        var result: [(Vec3, Double, RGB)] = [
            (Vec3(2.9, 1.0, 4.0 - bob), 0.6, RGB(0x2E7BFF)),
            (Vec3(2.35, -2.5, 1.0 + bob), 0.26, RGB(0x7CF7DE)),
            (Vec3(-2.3, 1.7, 0.9 - bob), 0.3, RGB(0xFF3D81)),
        ]
        // Beads riding the ring.
        for i in 0..<3 {
            let theta = time * 0.55 + Double(i) * 2.09
            result.append((ringPoint(theta), 0.13, RGB(0xFF5C9A)))
        }
        return result
    }

    private func ringPoint(_ theta: Double) -> Vec3 {
        Vec3(Self.ringRadius * cos(theta), Self.ringRadius * sin(theta), 2.0 + 0.8 * sin(theta - 0.8))
    }

    private func rings() -> [(Vec3, Vec3, RGB, Double)] {
        let count = 72
        return (0..<count).map { i in
            let a = Double(i) / Double(count) * 2 * .pi
            let b = Double(i + 1) / Double(count) * 2 * .pi
            let tint = RGB(0x7CF7DE).mix(RGB(0x2E7BFF), 0.5 - 0.5 * cos(a))
            return (ringPoint(a), ringPoint(b), tint, 2.4)
        }
    }

    private func plinthEdge() -> [(Vec3, Vec3, RGB, Double)] {
        let count = 60
        return (0..<count).map { i in
            let a = Double(i) / Double(count) * 2 * .pi
            let b = Double(i + 1) / Double(count) * 2 * .pi
            return (Vec3(3.0 * cos(a), 3.0 * sin(a), 0), Vec3(3.0 * cos(b), 3.0 * sin(b), 0), RGB(0x7CF7DE), 1.6)
        }
    }

    // MARK: Drawing

    private func drawFloor(in context: inout GraphicsContext, camera: Camera) {
        let center = camera.point(Vec3(0, 0, -0.4))
        let radius = 5.2 * camera.scale
        let rect = CGRect(x: center.x - radius, y: center.y - radius * 0.42, width: radius * 2, height: radius * 0.84)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [Theme.teal.opacity(0.42), Theme.ocean.opacity(0.12), .clear]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    private func drawFace(_ face: Face, in context: inout GraphicsContext, camera: Camera) {
        let points = face.points.map(camera.point)
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        let top = points.map(\.y).min() ?? 0
        let bottom = points.map(\.y).max() ?? 0
        let midX = points.map(\.x).average

        switch face.kind {
        case .portal:
            context.fill(path, with: .linearGradient(
                Gradient(colors: [Theme.mint.opacity(0.85), Theme.teal.opacity(0.55), Theme.ocean.opacity(0.25)]),
                startPoint: CGPoint(x: midX, y: top), endPoint: CGPoint(x: midX, y: bottom)
            ))
        case .solid:
            let material = face.material
            let lambert = max(0, face.normal.dot(Self.light))
            let facing = abs(camera.toView(face.normal).y)
            var base = material.shadow.mix(material.lit, 0.12 + 0.88 * lambert)
            base = base.mix(RGB(0x7CF7DE), pow(1 - min(1, facing), 3) * 0.3)
            if material.emissive {
                base = material.lit.mix(RGB(0xFFFFFF), 0.25 * lambert)
            }
            context.fill(path, with: .linearGradient(
                Gradient(colors: [base.scaled(1.14).color(), base.scaled(0.8).color()]),
                startPoint: CGPoint(x: midX, y: top), endPoint: CGPoint(x: midX, y: bottom)
            ))
            // Same-colour stroke closes hairline seams; a faint light edge on lit faces gives the clay its crispness.
            context.stroke(path, with: .color(base.color()), lineWidth: 0.8)
            if lambert > 0.55 {
                context.stroke(path, with: .color(.white.opacity(0.14)), lineWidth: 0.8)
            }
        }
    }

    private func drawSphere(_ center: Vec3, _ radius: Double, _ color: RGB, in context: inout GraphicsContext, camera: Camera) {
        let c = camera.point(center)
        let r = camera.size(radius, at: center)
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect.insetBy(dx: -r * 0.9, dy: -r * 0.9)), with: .radialGradient(
            Gradient(colors: [color.color(0.35), .clear]), center: c, startRadius: r * 0.6, endRadius: r * 1.9
        ))
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.mix(RGB(0xFFFFFF), 0.7).color(), color.color(), color.scaled(0.28).color()]),
            center: CGPoint(x: c.x + r * 0.32, y: c.y - r * 0.38), startRadius: 0, endRadius: r * 1.45
        ))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(RGB(0x7CF7DE).color(0.22)), lineWidth: 1)
    }

    private func drawSegment(_ a: Vec3, _ b: Vec3, _ color: RGB, _ width: Double, in context: inout GraphicsContext, camera: Camera) {
        var path = Path()
        path.move(to: camera.point(a))
        path.addLine(to: camera.point(b))
        let k = camera.size(1, at: a.mid(b)) / camera.scale
        context.stroke(path, with: .color(color.color(0.22)), style: StrokeStyle(lineWidth: width * 3.2 * k, lineCap: .round))
        context.stroke(path, with: .color(color.mix(RGB(0xFFFFFF), 0.25).color()), style: StrokeStyle(lineWidth: width * k, lineCap: .round))
    }

    private func drawGlow(_ center: Vec3, _ radius: Double, _ color: Color, in context: inout GraphicsContext, camera: Camera) {
        let c = camera.point(center)
        let r = camera.size(radius, at: center)
        context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .radialGradient(
            Gradient(colors: [color, .clear]), center: c, startRadius: 0, endRadius: r
        ))
    }
}

// MARK: - Math

struct Vec3 {
    var x, y, z: Double

    init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func * (a: Vec3, k: Double) -> Vec3 { Vec3(a.x * k, a.y * k, a.z * k) }
    func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }
    func mid(_ o: Vec3) -> Vec3 { (self + o) * 0.5 }
    var normalized: Vec3 {
        let length = (x * x + y * y + z * z).squareRoot()
        return length > 0 ? self * (1 / length) : self
    }

    /// Turns around the z axis, then the x axis.
    func rotated(z az: Double, x ax: Double) -> Vec3 {
        let x1 = x * cos(az) - y * sin(az)
        let y1 = x * sin(az) + y * cos(az)
        return Vec3(x1, y1 * cos(ax) - z * sin(ax), y1 * sin(ax) + z * cos(ax))
    }
}

/// Orbits the origin (yaw), looks down a little (pitch), with soft perspective.
/// View space is (right, depth, up); larger depth is farther away.
struct Camera {
    var yaw: Double
    var pitch: Double
    var scale: Double
    var origin: CGPoint
    var focal = 18.0

    func toView(_ p: Vec3) -> Vec3 {
        let x = p.x * cos(yaw) - p.y * sin(yaw)
        let y = p.x * sin(yaw) + p.y * cos(yaw)
        return Vec3(x, y * cos(pitch) - p.z * sin(pitch), p.z * cos(pitch) + y * sin(pitch))
    }

    func project(_ v: Vec3) -> CGPoint {
        let k = focal / (focal + v.y)
        return CGPoint(x: origin.x + v.x * scale * k, y: origin.y - v.z * scale * k)
    }

    func point(_ p: Vec3) -> CGPoint { project(toView(p)) }
    func depth(_ p: Vec3) -> Double { toView(p).y }
    func size(_ r: Double, at p: Vec3) -> Double { r * scale * focal / (focal + depth(p)) }
}

struct RGB {
    var r, g, b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    func mix(_ o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    func scaled(_ k: Double) -> RGB { RGB(r: min(r * k, 1), g: min(g * k, 1), b: min(b * k, 1)) }

    func color(_ opacity: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: opacity) }
}

struct Clay {
    var shadow: RGB
    var lit: RGB
    var emissive = false

    static let arch = Clay(shadow: RGB(0x05132F), lit: RGB(0x2C9BEA))
    static let stair = Clay(shadow: RGB(0x083D52), lit: RGB(0x86FBE4))
    static let stairOff = Clay(shadow: RGB(0x0A1530), lit: RGB(0x2A3C62))
    static let plinth = Clay(shadow: RGB(0x040B1C), lit: RGB(0x173462))
    static let pen = Clay(shadow: RGB(0x56082D), lit: RGB(0xFF5C9A))
    static let play = Clay(shadow: RGB(0x12A894), lit: RGB(0xB8FFF0), emissive: true)
}

struct Face {
    enum Kind { case solid, portal }

    var points: [Vec3]
    var normal: Vec3
    var material: Clay
    var kind = Kind.solid
    var doubleSided = false
    /// Nudges the sort for faces that should always sit under the rest (the plinth top).
    var bias = 0.0

    func rotated(z: Double, x: Double) -> Face {
        var face = self
        face.points = points.map { $0.rotated(z: z, x: x) }
        face.normal = normal.rotated(z: z, x: x)
        return face
    }

    func moved(by offset: Vec3) -> Face {
        var face = self
        face.points = points.map { $0 + offset }
        return face
    }
}

enum Mesh {
    static func box(_ lo: Vec3, _ hi: Vec3, material: Clay) -> [Face] {
        let (a, b) = (lo, hi)
        func face(_ points: [Vec3], _ normal: Vec3) -> Face { Face(points: points, normal: normal, material: material) }
        return [
            face([Vec3(a.x, a.y, b.z), Vec3(b.x, a.y, b.z), Vec3(b.x, b.y, b.z), Vec3(a.x, b.y, b.z)], Vec3(0, 0, 1)),
            face([Vec3(a.x, a.y, a.z), Vec3(b.x, a.y, a.z), Vec3(b.x, b.y, a.z), Vec3(a.x, b.y, a.z)], Vec3(0, 0, -1)),
            face([Vec3(a.x, a.y, a.z), Vec3(b.x, a.y, a.z), Vec3(b.x, a.y, b.z), Vec3(a.x, a.y, b.z)], Vec3(0, -1, 0)),
            face([Vec3(a.x, b.y, a.z), Vec3(b.x, b.y, a.z), Vec3(b.x, b.y, b.z), Vec3(a.x, b.y, b.z)], Vec3(0, 1, 0)),
            face([Vec3(a.x, a.y, a.z), Vec3(a.x, b.y, a.z), Vec3(a.x, b.y, b.z), Vec3(a.x, a.y, b.z)], Vec3(-1, 0, 0)),
            face([Vec3(b.x, a.y, a.z), Vec3(b.x, b.y, a.z), Vec3(b.x, b.y, b.z), Vec3(b.x, a.y, b.z)], Vec3(1, 0, 0)),
        ]
    }

    /// Extrudes an outline drawn in the x–z plane (x right, z up) from depth y0 to y1.
    static func prism(_ outline: [(Double, Double)], y0: Double, y1: Double, material: Clay) -> [Face] {
        var faces = [
            Face(points: outline.map { Vec3($0.0, y0, $0.1) }, normal: Vec3(0, -1, 0), material: material),
            Face(points: outline.map { Vec3($0.0, y1, $0.1) }, normal: Vec3(0, 1, 0), material: material),
        ]
        var area = 0.0
        for i in outline.indices {
            let a = outline[i], b = outline[(i + 1) % outline.count]
            area += a.0 * b.1 - b.0 * a.1
        }
        let turn = area > 0 ? 1.0 : -1.0
        for i in outline.indices {
            let a = outline[i], b = outline[(i + 1) % outline.count]
            let normal = Vec3((b.1 - a.1) * turn, 0, -(b.0 - a.0) * turn).normalized
            faces.append(Face(points: [Vec3(a.0, y0, a.1), Vec3(b.0, y0, b.1), Vec3(b.0, y1, b.1), Vec3(a.0, y1, a.1)],
                              normal: normal, material: material))
        }
        return faces
    }

    static func cylinder(radius: Double, z0: Double, z1: Double, segments: Int, material: Clay) -> [Face] {
        let ring = (0..<segments).map { i -> (Double, Double) in
            let a = Double(i) / Double(segments) * 2 * .pi
            return (radius * cos(a), radius * sin(a))
        }
        var top = Face(points: ring.map { Vec3($0.0, $0.1, z1) }, normal: Vec3(0, 0, 1), material: material)
        top.bias = 50
        var faces = [top]
        for i in 0..<segments {
            let a = ring[i], b = ring[(i + 1) % segments]
            let mid = (Double(i) + 0.5) / Double(segments) * 2 * .pi
            faces.append(Face(points: [Vec3(a.0, a.1, z0), Vec3(b.0, b.1, z0), Vec3(b.0, b.1, z1), Vec3(a.0, a.1, z1)],
                              normal: Vec3(cos(mid), sin(mid), 0), material: material))
        }
        return faces
    }

    /// The arch seen from the front: two legs and a round top, open at the bottom.
    static func archOutline(outer: Double, inner: Double, spring: Double, steps: Int = 16) -> [(Double, Double)] {
        var points: [(Double, Double)] = [(-outer, 0), (-inner, 0)]
        for i in 0...steps {
            let a = Double.pi - Double(i) / Double(steps) * .pi
            points.append((inner * cos(a), spring + inner * sin(a)))
        }
        points += [(inner, 0), (outer, 0)]
        for i in 0...steps {
            let a = Double(i) / Double(steps) * .pi
            points.append((outer * cos(a), spring + outer * sin(a)))
        }
        return points
    }

    /// The opening inside the arch.
    static func doorway(halfWidth: Double, spring: Double, steps: Int = 16) -> [(Double, Double)] {
        var points: [(Double, Double)] = [(-halfWidth, 0), (halfWidth, 0)]
        for i in 0...steps {
            let a = Double(i) / Double(steps) * .pi
            points.append((halfWidth * cos(a), spring + halfWidth * sin(a)))
        }
        return points
    }
}

private extension Array where Element == Double {
    var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
}

private extension Array where Element == CGFloat {
    var average: CGFloat { isEmpty ? 0 : reduce(0, +) / CGFloat(count) }
}
