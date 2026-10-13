import SwiftUI
import MoeedCore

/// A lecture being prepared, like a packet coming off the copier. No spinner: a checklist ticked
/// in red pen, and each page gets inked as its explanation is written.
struct ImportView: View {
    @Environment(AppRouter.self) private var router
    @State private var onlyReady = false
    private let job = Samples.importJob

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    Button { router.route = .library } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 12, weight: .bold))
                            Text("المكتبة")
                        }
                    }
                    .buttonStyle(.underlined)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("تجهيز المحاضرة")
                            .font(Theme.text(20, .heavy))
                            .foregroundStyle(Theme.ink)
                        Text(verbatim: "\(job.courseCode) · \(job.fileName)")
                            .font(Theme.serif(13.5))
                            .italic()
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                Hairline(color: Theme.ink.opacity(0.35))
            }
            .padding(.horizontal, 28)

            HStack(alignment: .top, spacing: 28) {
                checklist
                    .frame(width: 370)
                slides
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Desk())
    }

    // MARK: Checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: job.fileName)
                .font(Theme.serif(22, .bold))
                .foregroundStyle(Theme.ink)
            Text("\(String(job.slideCount)) سلايد · \(job.courseCode)")
                .font(Theme.text(13))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 2)
            DoubleRule()
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(ImportStage.allCases, id: \.self) { stage in
                    StageRow(stage: stage, job: job)
                    Hairline(color: Theme.rule)
                }
            }
            .padding(.top, 6)

            Spacer(minLength: 16)

            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Theme.red).frame(width: 2)
                Text("تقدر تبدأ من السلايدات الجاهزة، والباقي يتجهّز وانت تذاكر.")
                    .font(Theme.text(14.5, .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 16)

            Button { router.route = .player } label: {
                HStack(spacing: 8) {
                    Text("ابدأ من السلايد 1")
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ink())
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .paperSheet()
    }

    // MARK: Slides

    private var slides: some View {
        let numbers = Array(1...job.slideCount).filter { !onlyReady || job.state(ofSlide: $0) == .ready }
        let columns = 8
        let rows = stride(from: 0, to: numbers.count, by: columns).map { Array(numbers[$0..<min($0 + columns, numbers.count)]) }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("الصفحات")
                    .font(Theme.text(18, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(String(job.scripted)) جاهزة من \(String(job.slideCount))")
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                HStack(spacing: 0) {
                    Button { onlyReady = false } label: { Text("الكل") }
                        .buttonStyle(.chip(selected: !onlyReady))
                    Button { onlyReady = true } label: { Text("الجاهزة") }
                        .buttonStyle(.chip(selected: onlyReady))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(rows[row], id: \.self) { number in
                            PageThumb(number: number, state: job.state(ofSlide: number))
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

    private var isDone: Bool { stage < job.stage }
    private var isCurrent: Bool { stage == job.stage }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PenCheckbox(isOn: isDone)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.text(16, isCurrent ? .heavy : .semibold))
                    .foregroundStyle(isDone || isCurrent ? Theme.ink : Theme.mark)
                    .highlighted(isCurrent, seed: 3)
                Text(detail)
                    .font(Theme.text(13.5))
                    .foregroundStyle(Theme.inkSoft)
                if isCurrent && stage == .scripting {
                    HStack(spacing: 10) {
                        ProgressTrack(value: Double(job.scripted) / Double(job.slideCount), height: 8)
                        Text("\(String(job.scripted)) من \(String(job.slideCount))")
                            .font(Theme.serif(13, .bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
            if isDone {
                Text("تم")
                    .font(Theme.text(12.5, .bold))
                    .foregroundStyle(Theme.red)
            }
        }
        .padding(.vertical, 13)
        .fixedSize(horizontal: false, vertical: true)
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

/// A page of the packet. Ready pages are printed and carry the tutor's ink; the one being written
/// is half-inked under the highlighter; the rest are blank stock waiting in the tray.
private struct PageThumb: View {
    var number: Int
    var state: SlideJobState

    private static let size = CGSize(width: 76, height: 57)
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
        let waiting = state == .waiting
        ZStack(alignment: .topLeading) {
            Rectangle().fill(waiting ? Theme.paper.opacity(0.55) : .white)
            if !waiting {
                VStack(alignment: .leading, spacing: 5) {
                    Rectangle().fill(Theme.slideTitle.opacity(0.6)).frame(width: lineA, height: 4)
                    Rectangle().fill(Theme.slideRule).frame(width: lineB, height: 3)
                    Rectangle().fill(Theme.slideRule).frame(width: lineA - 8, height: 3)
                }
                .padding(8)
                InkPath(mark: Self.marks[number % Self.marks.count], scale: scale)
                    .trim(from: 0, to: state == .ready ? 1 : 0.55)
                    .stroke(Theme.red, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            Text(verbatim: String(number))
                .font(Theme.serif(9.5, .semibold).monospacedDigit())
                .foregroundStyle(Theme.mark)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay {
            if waiting {
                Rectangle().strokeBorder(Theme.mark.opacity(0.7), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
            } else {
                Rectangle().strokeBorder(Theme.ink.opacity(0.15), lineWidth: 0.5)
            }
        }
        .background {
            if state == .writing {
                HighlighterSwipe(seed: number)
                    .fill(Theme.highlighter.opacity(0.85))
                    .padding(-5)
            }
        }
        .shadow(color: waiting ? .clear : Theme.ink.opacity(0.16), radius: 1.5, y: 1)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text("سلايد \(String(number))"))
        .accessibilityValue(Text(state == .ready ? "جاهزة" : state == .writing ? "يتجهّز" : "بالانتظار"))
    }
}
