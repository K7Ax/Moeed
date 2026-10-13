import SwiftUI
import MoeedCore

/// A lecture being prepared. No spinner: each slide gets inked as its explanation is written.
struct ImportView: View {
    @Environment(AppRouter.self) private var router
    @State private var onlyReady = false
    private let job = Samples.importJob

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Button { router.route = .library } label: {
                    Label("المكتبة", systemImage: "chevron.backward")
                }
                .buttonStyle(.outline(height: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text("تجهيز المحاضرة")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: "\(job.courseCode) · \(job.fileName)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 28) {
                statusPanel
                    .frame(width: 380)
                slides
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Aurora(intensity: 0.9))
    }

    // MARK: Status

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // The sculpture builds itself: one lit step for each finished stage.
            LogoSculpture(litSteps: min(ImportStage.allCases.filter { $0 < job.stage }.count, 3))
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .padding(.top, -10)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 2) {
                        Text(verbatim: job.fileName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(String(job.slideCount)) سلايد · \(job.courseCode)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .offset(y: 30)
                }
                .padding(.bottom, 30)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(ImportStage.allCases, id: \.self) { stage in
                    StageRow(stage: stage, job: job, isLast: stage == ImportStage.allCases.last)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.working)
                Text("تقدر تبدأ من السلايدات الجاهزة، والباقي يتجهّز وانت تذاكر.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.workingTint, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

            Button { router.route = .player } label: {
                HStack(spacing: 8) {
                    Text("ابدأ من السلايد 1")
                    Image(systemName: "chevron.forward")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .card()
    }

    // MARK: Slides

    private var slides: some View {
        let numbers = Array(1...job.slideCount).filter { !onlyReady || job.state(ofSlide: $0) == .ready }
        let columns = 8
        let rows = stride(from: 0, to: numbers.count, by: columns).map { Array(numbers[$0..<min($0 + columns, numbers.count)]) }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("السلايدات")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(String(job.scripted)) جاهزة من \(String(job.slideCount))")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button { onlyReady = false } label: { Text("الكل") }
                    .buttonStyle(.chip(selected: !onlyReady))
                Button { onlyReady = true } label: { Text("الجاهزة") }
                    .buttonStyle(.chip(selected: onlyReady))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(rows[row], id: \.self) { number in
                            SlideThumb(number: number, state: job.state(ofSlide: number))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StageRow: View {
    var stage: ImportStage
    var job: ImportJob
    var isLast: Bool

    private var isDone: Bool { stage < job.stage }
    private var isCurrent: Bool { stage == job.stage }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                indicator
                if !isLast {
                    Rectangle()
                        .fill(isDone ? Theme.correct : Theme.line)
                        .frame(width: 2)
                        .frame(minHeight: 26, maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(isDone || isCurrent ? Theme.ink : Theme.muted)
                Text(detail)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.muted)
                if isCurrent && stage == .scripting {
                    HStack(spacing: 10) {
                        ProgressTrack(value: Double(job.scripted) / Double(job.slideCount), tint: Theme.working, height: 6)
                        Text("\(String(job.scripted)) من \(String(job.slideCount))")
                            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.workingText)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var indicator: some View {
        if isDone {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onBright)
                .frame(width: 24, height: 24)
                .background(Theme.correct, in: Circle())
                .glow(Theme.correct, radius: 6, opacity: 0.6)
        } else if isCurrent {
            Circle()
                .strokeBorder(Theme.working, lineWidth: 2)
                .overlay(Circle().fill(Theme.working).padding(6))
                .frame(width: 24, height: 24)
                .glow(Theme.working, radius: 8, opacity: 0.8)
        } else {
            Circle()
                .strokeBorder(Theme.faint, lineWidth: 2)
                .frame(width: 24, height: 24)
        }
    }

    private var title: LocalizedStringKey {
        switch stage {
        case .reading: return "قراءة الملف"
        case .regions: return "تحديد المناطق"
        case .scripting: return "كتابة الشرح"
        case .verifying: return "مراجعة الشرح"
        }
    }

    private var detail: LocalizedStringKey {
        switch stage {
        case .reading: return "النص والمعادلات والرسومات"
        case .regions: return "وين كل عنوان ومعادلة ورسم"
        case .scripting: return "حبر وكلام لكل سلايد"
        case .verifying: return "نتأكد إن كل علامة في مكانها"
        }
    }
}

/// A miniature slide. Ready slides carry the tutor's ink; the one being written is half-drawn.
private struct SlideThumb: View {
    var number: Int
    var state: SlideJobState

    private static let size = CGSize(width: 78, height: 58)
    private static let marks: [InkMark] = [
        .circle(center: SlidePoint(520, 380), rx: 150, ry: 110),
        .underline(from: SlidePoint(80, 250), to: SlidePoint(470, 250)),
        .box(SlideRect(80, 330, 300, 150)),
        .arrow(from: SlidePoint(160, 470), to: SlidePoint(560, 300), bend: -0.2),
    ]

    var body: some View {
        let scale = Self.size.width / 800
        let lineA: CGFloat = [44, 36, 50, 40][number % 4]
        let lineB: CGFloat = [30, 46, 38, 52][(number + 1) % 4]
        ZStack(alignment: .topLeading) {
            Color.white
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(Theme.slideTitle.opacity(0.55)).frame(width: lineA, height: 4)
                Capsule().fill(Theme.slideRule).frame(width: lineB, height: 3)
                Capsule().fill(Theme.slideRule).frame(width: lineA - 8, height: 3)
            }
            .padding(8)
            if state != .waiting {
                InkPath(mark: Self.marks[number % Self.marks.count], scale: scale)
                    .trim(from: 0, to: state == .ready ? 1 : 0.55)
                    .stroke(Theme.pen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            Text(verbatim: String(number))
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(state == .writing ? Theme.working : .white.opacity(0.4), lineWidth: state == .writing ? 2 : 0.5)
        )
        .shadow(color: state == .writing ? Theme.working.opacity(0.6) : state == .ready ? Theme.teal.opacity(0.25) : .clear, radius: 10)
        .opacity(state == .waiting ? 0.28 : 1)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text("سلايد \(String(number))"))
        .accessibilityValue(Text(state == .ready ? "جاهزة" : state == .writing ? "يتجهّز" : "بالانتظار"))
    }
}
