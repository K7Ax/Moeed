import MoeedCore
import SwiftUI

/// Where a lecture stands, as its cover shows it.
public enum CoverState: Hashable, Sendable {
    case plain
    case done
    case current(progress: Double)
    case preparing(progress: Double)

    init(_ lecture: Lecture) {
        switch lecture.status {
        case let .preparing(progress): self = .preparing(progress: progress)
        case .ready where lecture.progress >= 1: self = .done
        case .ready where lecture.progress > 0: self = .current(progress: lecture.progress)
        case .ready: self = .plain
        }
    }
}

/// A lecture's cover, set the way ثمانية sets its shows: the subject's word large as the art,
/// its line drawing behind, the course code and number small, the English title in Brygada.
/// A finished lecture gets the tutor's tick; one in progress, a thin bar; one being prepared,
/// a turning phasor and a shimmering bar.
public struct CoverArt: View {
    let cover: Cover
    var size: CGFloat
    var state: CoverState
    var delay: Double

    public init(_ cover: Cover, size: CGFloat = 132, state: CoverState = .plain, delay: Double = 0) {
        self.cover = cover
        self.size = size
        self.state = state
        self.delay = delay
    }

    public var body: some View {
        let pad = size * 0.085
        ZStack {
            cover.color
            LinearGradient(
                colors: [.white.opacity(0.18), .black.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.35, y: 1)
            )
            art
            words(pad: pad)
            marks(pad: pad)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.07, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("المحاضرة \(cover.number.eastern): \(cover.word)")
    }

    /// The line drawing, from the top-left, at 40 % white.
    private var art: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if case .preparing = state {
                    PhasorArt()
                } else {
                    CoverMotif(number: cover.number)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.4 * size * 0.76 / 100, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: size * 0.76, height: size * 0.76)
            .opacity(cover.number == 6 && !isPreparing ? 0 : 0.4)
            .offset(x: size * 0.12, y: size * 0.1)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func words(pad: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(Cover.code)
                    .font(Typeface.plex(max(9, size * 0.068), .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 0)
                Text(cover.number.eastern)
                    .font(Typeface.plex(size * 0.15, .bold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Text(cover.word)
                .font(Typeface.plex(size * 0.17, .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(cover.english)
                .font(Typeface.serif(max(9, size * 0.072), italic: true))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(pad)
        .padding(.bottom, hasBar ? pad * 0.3 : 0)
    }

    @ViewBuilder
    private func marks(pad: CGFloat) -> some View {
        switch state {
        case .done:
            InkOn(shape: InkTickShape(), color: Adaptive(.white, .white), lineWidth: size * 0.2 * 0.11, duration: 0.52, delay: delay + 0.6)
                .frame(width: size * 0.2, height: size * 0.2)
                .frame(width: size, height: size, alignment: .topLeading)
                .offset(x: pad * 0.7, y: size * 0.36)
                .environment(\.layoutDirection, .leftToRight)
        case let .current(progress):
            bar(progress, pad: pad, shimmer: false)
        case let .preparing(progress):
            bar(progress, pad: pad, shimmer: true)
        case .plain:
            EmptyView()
        }
    }

    /// A thin bar along the bottom, filling from the reading start.
    private func bar(_ progress: Double, pad: CGFloat, shimmer: Bool) -> some View {
        VStack {
            Spacer()
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.27))
                GeometryReader { geo in
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
                if shimmer { Shimmer(opacity: 0.8) }
            }
            .frame(height: 3)
            .clipShape(Capsule())
            .padding(.horizontal, pad)
            .padding(.bottom, pad * 0.55)
        }
    }

    private var isPreparing: Bool {
        if case .preparing = state { return true }
        return false
    }

    private var hasBar: Bool {
        switch state {
        case .current, .preparing: true
        default: false
        }
    }
}

/// Each lecture's subject as it's drawn on the board, in a 100-point square.
struct CoverMotif: Shape {
    var number: Int

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        func line(_ points: [(Double, Double)]) {
            guard let first = points.first else { return }
            path.move(to: p(first.0, first.1))
            for q in points.dropFirst() { path.addLine(to: p(q.0, q.1)) }
        }
        switch number {
        case 1: // a cell feeding a loop
            line([(22, 30), (78, 30), (78, 72), (22, 72), (22, 30)])
            line([(14, 46), (14, 56)])
            line([(8, 49), (8, 53)])
            line([(22, 51), (14, 51)])
        case 2: // a resistor
            line([(6, 52), (26, 52), (31, 38), (39, 66), (47, 38), (55, 66), (63, 38), (68, 52), (94, 52)])
        case 3: // currents meeting at a node
            line([(50, 50), (16, 26)])
            line([(50, 50), (84, 26)])
            line([(50, 50), (50, 90)])
            line([(30, 33), (24, 32), (26, 26)])
            line([(70, 33), (76, 32), (74, 26)])
            line([(47, 76), (50, 82), (53, 76)])
            path.addEllipse(in: CGRect(origin: p(45, 45), size: CGSize(width: 10 * s, height: 10 * s)))
        case 4: // a capacitor
            line([(6, 50), (42, 50)])
            line([(42, 28), (42, 72)])
            line([(58, 28), (58, 72)])
            line([(58, 50), (94, 50)])
        case 5: // a sine wave
            line((0...45).map { i in (4 + Double(i) * 2, 50 - 24 * sin(Double(i) / 45 * Double.pi * 3)) })
        default:
            break
        }
        return path
    }
}

/// The phasor, turning while its lecture is being prepared.
struct PhasorArt: View {
    @Environment(\.motionOff) private var motionOff

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 100
            ZStack {
                Circle()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.4 * s, dash: [3 * s, 5 * s]))
                    .frame(width: 64 * s, height: 64 * s)
                TimelineView(.animation(paused: motionOff)) { timeline in
                    let turn = motionOff ? 0.12 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.8) / 4.8
                    ZStack {
                        Path { p in
                            p.move(to: CGPoint(x: 50 * s, y: 50 * s))
                            p.addLine(to: CGPoint(x: 80 * s, y: 50 * s))
                            p.move(to: CGPoint(x: 72 * s, y: 44 * s))
                            p.addLine(to: CGPoint(x: 80 * s, y: 50 * s))
                            p.addLine(to: CGPoint(x: 72 * s, y: 56 * s))
                        }
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
                        Circle().fill(.white).frame(width: 7 * s, height: 7 * s)
                    }
                    .frame(width: geo.size.width, height: geo.size.width)
                    .rotationEffect(.degrees(-360 * turn))
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
