import MoeedCore
import SwiftUI

// The motion of «الأصلي»: staggered entrances, springs under the finger, covers that tilt toward
// the pointer, slow light behind the player, ink that writes itself. Every piece settles straight
// into its final state in snapshots and when Reduce Motion is on.

extension Animation {
    /// easeOutCubic, the curve every entrance and tween uses.
    static func settle(_ duration: Double) -> Animation { .timingCurve(0.33, 1, 0.68, 1, duration: duration) }
}

private struct MotionOffKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when things should appear in their final state: snapshots and Reduce Motion.
    var motionOff: Bool {
        get { self[MotionOffKey.self] }
        set { self[MotionOffKey.self] = newValue }
    }
}

/// Folds `isSnapshot` and Reduce Motion into `motionOff` once, at the top of a screen.
struct MotionPolicy: ViewModifier {
    @Environment(\.isSnapshot) private var isSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(\.motionOff, isSnapshot || reduceMotion)
    }
}

// MARK: - Entrances

/// Fades and lifts in once, `delay` seconds after it first appears.
struct Rise: ViewModifier {
    var delay: Double
    var dy: CGFloat
    @Environment(\.motionOff) private var motionOff
    @State private var shown = false

    func body(content: Content) -> some View {
        let on = shown || motionOff
        content
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : dy)
            .onAppear {
                guard !shown, !motionOff else { return }
                withAnimation(.settle(0.56).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func rise(_ delay: Double = 0, dy: CGFloat = 18) -> some View {
        modifier(Rise(delay: delay, dy: dy))
    }
}

/// A value that eases from zero to `target` when it first shows, and to each new target after.
struct Tween<Content: View>: View {
    var target: Double
    var duration: Double = 0.8
    var delay: Double = 0
    var content: (Double) -> Content
    @Environment(\.motionOff) private var motionOff
    @State private var value: Double = 0

    init(target: Double, duration: Double = 0.8, delay: Double = 0, @ViewBuilder content: @escaping (Double) -> Content) {
        self.target = target
        self.duration = duration
        self.delay = delay
        self.content = content
    }

    var body: some View {
        content(motionOff ? target : value)
            .onAppear { go() }
            .onChange(of: target) { _, _ in go() }
    }

    private func go() {
        guard !motionOff else { return }
        withAnimation(.settle(duration).delay(delay)) { value = target }
    }
}

/// A whole number that counts up as it animates, in Latin figures.
struct CountingText: View, Animatable {
    var value: Double
    var suffix = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: Int(value.rounded()).figures + suffix)
    }
}

/// Counts up to `to` once it shows.
struct Count: View {
    var to: Int
    var delay: Double = 0
    var suffix = ""

    var body: some View {
        Tween(target: Double(to), duration: 1.1, delay: delay) { v in
            CountingText(value: v, suffix: suffix)
        }
    }
}

// MARK: - Press and hover

/// Springs down under the finger and back with a little overshoot; tints on pointer hover.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var hover: Adaptive?
    var radius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, scale: scale, hoverFill: hover, radius: radius)
    }
}

private struct PressBody: View {
    let configuration: ButtonStyleConfiguration
    let scale: CGFloat
    let hoverFill: Adaptive?
    let radius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        configuration.label
            .background {
                if let hoverFill, hovering, isEnabled {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(hoverFill)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(configuration.isPressed ? .spring(response: 0.2, dampingFraction: 1) : .spring(response: 0.34, dampingFraction: 0.55), value: configuration.isPressed)
            .onHover { hovering = $0 }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension ButtonStyle where Self == PressStyle {
    static func press(_ scale: CGFloat = 0.96, hover: Adaptive? = nil, radius: CGFloat = 12) -> PressStyle {
        PressStyle(scale: scale, hover: hover, radius: radius)
    }
}

/// Tilts toward the pointer in 3D, lifts a touch, and catches a band of light across its face.
/// (Under a finger the press spring does this job; a drag here would fight the shelf's scroll.)
struct Tilt: ViewModifier {
    var maxAngle: Double = 8
    var radius: CGFloat
    @Environment(\.motionOff) private var motionOff
    @State private var size = CGSize(width: 1, height: 1)
    @State private var point = CGPoint.zero
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .overlay { glare }
            .rotation3DEffect(.degrees(Double(point.x) * maxAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-point.y) * maxAngle), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(lifted ? 1.03 : 1)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { size = geo.size }
                        .onChange(of: geo.size) { _, new in size = new }
                }
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case let .active(location): aim(location, lift: true)
                case .ended: aim(nil, lift: false)
                }
            }
    }

    private var glare: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.16), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.7, height: geo.size.height + 80)
                .rotationEffect(.degrees(18))
                .offset(x: geo.size.width * 0.15 + point.x * 120, y: -40)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .opacity(lifted ? 1 : 0)
        .allowsHitTesting(false)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func aim(_ location: CGPoint?, lift: Bool) {
        guard !motionOff else { return }
        let target = location.map {
            CGPoint(x: min(1, max(-1, $0.x / size.width * 2 - 1)), y: min(1, max(-1, $0.y / size.height * 2 - 1)))
        } ?? .zero
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            point = target
            lifted = lift
        }
    }
}

extension View {
    func tilt(radius: CGFloat, maxAngle: Double = 8) -> some View {
        modifier(Tilt(maxAngle: maxAngle, radius: radius))
    }
}

// MARK: - Light

/// The player's light: pools of the logo's teals drifting over near-black, as Apple Music does.
struct Ambient: View {
    var dim: Double = 1
    @Environment(\.motionOff) private var motionOff

    init(dim: Double = 1) {
        self.dim = dim
    }

    private struct Pool {
        let color: Color, size: CGFloat, x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat, period: Double, phase: Double, opacity: Double
    }

    private let pools: [Pool] = [
        Pool(color: Stage.ambient[0], size: 1.1, x: 0.82, y: 0.12, dx: 0.08, dy: 0.06, period: 19, phase: 0, opacity: 0.85),
        Pool(color: Stage.ambient[1], size: 1.0, x: 0.12, y: 0.85, dx: 0.10, dy: 0.05, period: 23, phase: 0.4, opacity: 0.9),
        Pool(color: Stage.ambient[2], size: 0.6, x: 0.35, y: 0.30, dx: 0.12, dy: 0.09, period: 17, phase: 0.9, opacity: 0.38),
        Pool(color: Stage.ambient[3], size: 0.8, x: 0.62, y: 0.95, dx: 0.07, dy: 0.08, period: 27, phase: 0.2, opacity: 0.7),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: motionOff)) { timeline in
            let t = motionOff ? 4.0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let m = max(size.width, size.height)
                for pool in pools {
                    let f = 2 * Double.pi * ((t / pool.period + pool.phase).truncatingRemainder(dividingBy: 1))
                    let d = m * pool.size * (1 + 0.15 * sin(f))
                    let cx = size.width * pool.x + m * pool.dx * sin(f)
                    let cy = size.height * pool.y - m * pool.dy * cos(f)
                    let rect = CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)
                    context.opacity = pool.opacity * dim
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(stops: [
                                .init(color: pool.color, location: 0),
                                .init(color: pool.color.opacity(0.42), location: 0.5),
                                .init(color: pool.color.opacity(0), location: 1),
                            ]),
                            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: d / 2
                        )
                    )
                }
                context.opacity = 1
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.18)))
            }
        }
        .background(Stage.deep)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small dot that breathes: live, now, in progress.
struct Pulse: View {
    var color: Color
    var size: CGFloat = 8
    @Environment(\.motionOff) private var motionOff

    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        TimelineView(.animation(paused: motionOff)) { timeline in
            let f = motionOff ? 0.3 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: size * 2.4, height: size * 2.4)
                    .scaleEffect(0.4 + 0.7 * f)
                    .opacity(f < 0.7 ? 0.45 * (1 - f / 0.7) : 0)
                Circle().fill(color).frame(width: size, height: size)
            }
            .frame(width: size * 2.4, height: size * 2.4)
        }
        .accessibilityHidden(true)
    }
}

/// A light band that sweeps across whatever it sits in: something is being made.
struct Shimmer: View {
    var color: Color = .white
    var opacity: Double = 0.5
    @Environment(\.motionOff) private var motionOff

    init(color: Color = .white, opacity: Double = 0.5) {
        self.color = color
        self.opacity = opacity
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: motionOff)) { timeline in
                let f = motionOff ? 0.4 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
                LinearGradient(colors: [color.opacity(0), color, color.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70)
                    .offset(x: geo.size.width - (geo.size.width + 70) * f)
            }
        }
        .opacity(opacity)
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Rings and ink

/// A progress ring, drawn round from the top.
struct Ring: View {
    var value: Double
    var stroke: CGFloat
    var color: Adaptive
    var track: Adaptive
    var dashed = false

    var body: some View {
        ZStack {
            Circle()
                .inset(by: stroke / 2)
                .stroke(track, style: StrokeStyle(lineWidth: stroke, dash: dashed ? [2, 3.2] : []))
            if value > 0.001 {
                Circle()
                    .inset(by: stroke / 2)
                    .trim(from: 0, to: min(1, value))
                    .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

/// Draws a shape's outline on once, `delay` seconds after it first appears.
struct InkOn<S: Shape>: View {
    var shape: S
    var color: Adaptive
    var lineWidth: CGFloat
    var duration: Double = 0.6
    var delay: Double = 0

    var body: some View {
        Tween(target: 1, duration: duration, delay: delay) { p in
            shape
                .trim(from: 0, to: p)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A hand-written tick.
struct InkTickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(4, 13))
        path.addQuadCurve(to: p(9, 19), control: p(6.5, 14.5))
        path.addQuadCurve(to: p(21, 4), control: p(13, 9))
        return path
    }
}
