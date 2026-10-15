import SwiftUI

/// An icon drawn the way the tutor writes: each stroke thin where the pen lands and lifts, full in
/// the middle, a little wider across the broad nib's angle, with one fixed lean of the hand.
/// When it becomes `active` it writes itself again, stroke by stroke, over about half a second.
public struct NibIcon: View {
    public enum Name: String, CaseIterable, Sendable {
        case home, library, review, plus
    }

    let name: Name
    var size: CGFloat
    var weight: CGFloat
    var active: Bool

    @State private var drawn: CGFloat = 1
    @Environment(\.motionOff) private var motionOff

    public init(_ name: Name, size: CGFloat = 22, weight: CGFloat = 2.3, active: Bool = false) {
        self.name = name
        self.size = size
        self.weight = weight
        self.active = active
    }

    public var body: some View {
        let strokes = NibGeometry.strokes(name)
        let total = strokes.reduce(0) { $0 + $1.count }
        ZStack {
            ForEach(strokes.indices, id: \.self) { k in
                NibStroke(
                    points: strokes[k],
                    seed: Double(k + 1),
                    weight: weight,
                    start: strokes[..<k].reduce(0) { $0 + $1.count },
                    total: total,
                    progress: drawn
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear { if active { write() } }
        .onChange(of: active) { _, isActive in
            if isActive { write() }
        }
    }

    private func write() {
        guard !motionOff else { return }
        drawn = 0
        withAnimation(.linear(duration: 0.52)) { drawn = 1 }
    }
}

/// One pen stroke as a filled outline, cut off at `progress` of the whole icon's ink.
struct NibStroke: Shape {
    let points: [CGPoint]
    let seed: Double
    let weight: CGFloat
    /// Where this stroke begins in the icon's running count of points.
    let start: Int
    let total: Int
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var count = points.count
        if progress < 1 {
            let eased = 1 - pow(1 - max(0, progress), 3)
            count = min(points.count, Int((eased * CGFloat(total)).rounded(.up)) - start)
        }
        guard count >= 2 else { return Path() }
        let outline = NibGeometry.outline(Array(points.prefix(count)), weight: weight, seed: seed)
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.addLines(outline.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
        path.closeSubpath()
        return path
    }
}

/// The strokes, on a 24-point grid, as dense polylines the nib outline is built around.
enum NibGeometry {
    static let slant = tan(7 * Double.pi / 180)
    static let nibAngle = 38 * Double.pi / 180

    static func strokes(_ name: NibIcon.Name) -> [[CGPoint]] {
        switch name {
        case .home:
            return [
                chain(seg(3.2, 11.8, 12, 4.2), seg(12, 4.2, 20.8, 11.8)),
                chain(seg(5.8, 10.2, 5.8, 20.2), seg(5.8, 20.2, 18.2, 20.2), seg(18.2, 20.2, 18.2, 10.2)),
                chain(seg(10.1, 20.2, 10.1, 15.4, k: 6), quad(10.1, 15.4, 12, 13.4, 13.9, 15.4, k: 8), seg(13.9, 15.4, 13.9, 20.2, k: 6)),
            ]
        case .library:
            return [
                chain(quad(12, 6.6, 7.4, 3.8, 2.8, 5.3), seg(2.8, 5.3, 2.8, 18.6), quad(2.8, 18.6, 7.6, 17.3, 12, 19.9)),
                chain(quad(12, 6.6, 16.6, 3.8, 21.2, 5.3), seg(21.2, 5.3, 21.2, 18.6), quad(21.2, 18.6, 16.4, 17.3, 12, 19.9)),
                seg(12, 6.8, 12, 19.4),
            ]
        case .review:
            let end: Double = 4.75
            let tip = CGPoint(x: 12 + 7.8 * cos(end) as Double, y: 12.4 + 7.8 * sin(end) as Double)
            return [
                arc(12, 12.4, 7.8, -0.35, end),
                arrowHead(tip, CGVector(dx: -sin(end), dy: cos(end))),
                chain(seg(12, 8.6, 12, 12.6, k: 6), seg(12, 12.6, 14.8, 14.4, k: 5)),
            ]
        case .plus:
            return [arc(12, 12, 8.8, -1.3, 5.2), seg(12, 7.8, 12, 16.2, k: 8), seg(7.8, 12, 16.2, 12, k: 8)]
        }
    }

    /// Slant and a touch of hand wobble, then the two edges of the nib's track, joined into one outline.
    static func outline(_ raw: [CGPoint], weight: CGFloat, seed: Double) -> [CGPoint] {
        let pts: [(x: Double, y: Double)] = raw.enumerated().map { i, p in
            let d: Double = Double(i)
            let x: Double = Double(p.x), y: Double = Double(p.y)
            let sx: Double = x - (y - 12) * slant + 0.16 * sin(d * 1.3 + seed)
            let sy: Double = y + 0.16 * cos(d * 1.1 + seed * 2)
            return (sx, sy)
        }
        let n = pts.count
        let w = Double(weight)
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        left.reserveCapacity(n)
        right.reserveCapacity(n)
        for i in 0..<n {
            let a = pts[max(0, i - 1)]
            let b = pts[min(n - 1, i + 1)]
            let len = max(hypot(b.x - a.x, b.y - a.y), .ulpOfOne)
            let tx = (b.x - a.x) / len
            let ty = (b.y - a.y) / len
            let f = n > 1 ? Double(i) / Double(n - 1) : 0.5
            let taper = sqrt(sin(Double.pi * (0.03 + 0.94 * f)))
            let across = abs(sin(atan2(ty, tx) - nibAngle))
            let body: Double = 0.14 + 0.86 * taper
            let nib: Double = 0.62 + 0.38 * across
            let hw: Double = w / 2 * body * nib
            left.append(CGPoint(x: pts[i].x - ty * hw, y: pts[i].y + tx * hw))
            right.append(CGPoint(x: pts[i].x + ty * hw, y: pts[i].y - tx * hw))
        }
        return left + right.reversed()
    }

    static func seg(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, k: Int = 12) -> [CGPoint] {
        (0...k).map { (i: Int) -> CGPoint in
            let f: Double = Double(i) / Double(k)
            let x: Double = x0 + (x1 - x0) * f
            let y: Double = y0 + (y1 - y0) * f
            return CGPoint(x: x, y: y)
        }
    }

    static func quad(_ ax: Double, _ ay: Double, _ cx: Double, _ cy: Double, _ bx: Double, _ by: Double, k: Int = 16) -> [CGPoint] {
        (0...k).map { (i: Int) -> CGPoint in
            let f: Double = Double(i) / Double(k)
            let u: Double = 1 - f
            let wa: Double = u * u, wc: Double = 2 * u * f, wb: Double = f * f
            let x: Double = wa * ax + wc * cx + wb * bx
            let y: Double = wa * ay + wc * cy + wb * by
            return CGPoint(x: x, y: y)
        }
    }

    static func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double, k: Int = 34) -> [CGPoint] {
        (0...k).map { (i: Int) -> CGPoint in
            let a: Double = a0 + (a1 - a0) * Double(i) / Double(k)
            let x: Double = cx + r * cos(a)
            let y: Double = cy + r * sin(a)
            return CGPoint(x: x, y: y)
        }
    }

    static func chain(_ parts: [CGPoint]...) -> [CGPoint] {
        parts.enumerated().reduce(into: []) { all, item in all += item.offset == 0 ? item.element : Array(item.element.dropFirst()) }
    }

    static func arrowHead(_ tip: CGPoint, _ dir: CGVector, len: Double = 3.4, spread: Double = 2.6) -> [CGPoint] {
        let (tx, ty) = (Double(tip.x), Double(tip.y))
        let (dx, dy) = (Double(dir.dx), Double(dir.dy))
        let (bx, by) = (tx - dx * len, ty - dy * len)
        return chain(
            seg(bx - dy * spread, by + dx * spread, tx, ty, k: 6),
            seg(tx, ty, bx + dy * spread, by - dx * spread, k: 6)
        )
    }
}
