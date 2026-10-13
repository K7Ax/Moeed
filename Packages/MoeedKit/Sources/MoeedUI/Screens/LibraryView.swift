import SwiftUI
import MoeedCore

/// The packet's front page: a masthead for the course, the lecture you were in as the lead story,
/// the lectures as a table of contents, and a sticky note for what needs another look.
struct LibraryView: View {
    @Environment(AppRouter.self) private var router
    private let course = Samples.course
    private let resume = Samples.resume

    init() {}

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            VStack(alignment: .leading, spacing: 0) {
                masthead
                lead
                    .padding(.top, 22)
                contents
                    .padding(.top, 22)
            }
            .padding(.horizontal, 34)
            .padding(.top, 24)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperSheet()
        }
        .padding(16)
        .background(Desk())
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: course.code)
                            .font(Theme.serif(15, .bold))
                        Text("الأسبوع 7 · الفصل الأول")
                            .font(Theme.text(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("الثلاثاء")
                            .font(Theme.text(12.5, .semibold))
                        Text("13 أكتوبر 2026")
                            .font(Theme.text(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .foregroundStyle(Theme.ink)
                Text(verbatim: course.name)
                    .font(Theme.text(46, .black))
                    .foregroundStyle(Theme.ink)
            }
            Hairline()
                .padding(.top, 10)
            HStack(spacing: 10) {
                Text("\(String(course.lectures.count)) محاضرات")
                Text(verbatim: "•")
                Text("\(String(Samples.reviewItems.count + 2)) للمراجعة")
                Text(verbatim: "•")
                Text("3 أسئلة مفتوحة")
            }
            .font(Theme.text(12.5, .medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.vertical, 6)
            DoubleRule()
        }
    }

    // MARK: Lead story

    private var lead: some View {
        HStack(alignment: .top, spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("كمّل من حيث وقفت")
                    .font(Theme.text(13.5, .bold))
                    .foregroundStyle(Theme.red)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "Lecture \(resume.lecture.number)")
                        .font(Theme.serif(17, .regular))
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                    Text(verbatim: resume.lecture.title)
                        .font(Theme.serif(34, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("السلايد \(String(resume.page)) من \(String(resume.lecture.slideCount)) · الخطوة \(String(resume.step)) من \(String(resume.stepCount)): \(resume.stepTitle)")
                    .font(Theme.text(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(Theme.leading(for: 15) / 2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    ProgressTrack(value: resume.lecture.progress)
                    Text(verbatim: "\(Int(resume.lecture.progress * 100))%")
                        .font(Theme.serif(15, .bold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 2)

                HStack(spacing: 16) {
                    Button { router.route = .player } label: {
                        HStack(spacing: 8) {
                            Text("كمّل الشرح")
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .buttonStyle(.ink(height: 48))
                    Text("\(String(resume.askCount)) أسئلة توقّع في الطريق")
                        .font(Theme.text(13))
                        .foregroundStyle(Theme.mark)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ColumnRule()

            VStack(alignment: .leading, spacing: 8) {
                SlideStage(page: Samples.sinePage, marks: [.circle(center: SlidePoint(430, 510), rx: 30, ry: 26)])
                    .frame(width: 290, height: 217.5)
                    .slideFrame()
                    .taped(.top, angle: -3)
                    .rotationEffect(.degrees(1.2))
                Text("سلايد \(String(resume.page)): وين وقف المعيد آخر مرة")
                    .font(Theme.text(12))
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 6)
            }
            .frame(width: 290)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Contents

    private var contents: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("المحاضرات")
                        .font(Theme.text(18, .heavy))
                    Spacer()
                    Text("المحتويات")
                        .font(Theme.text(12, .medium))
                        .foregroundStyle(Theme.mark)
                }
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 6)
                Hairline(weight: 1.5)
                ForEach(course.lectures) { lecture in
                    ContentsRow(lecture: lecture) {
                        router.route = lecture.status == .ready ? .player : .importing
                    }
                    Hairline(color: Theme.rule)
                }
                CutHere { router.route = .importing }
            }
            .frame(maxWidth: .infinity)

            ReviewNote(count: Samples.reviewItems.count + 2) { router.route = .review }
                .frame(width: 236)
                .padding(.top, 14)
        }
    }
}

/// One line of the table of contents: number, title, leader, and where it stands.
private struct ContentsRow: View {
    var lecture: Lecture
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Text(verbatim: String(format: "%02d", lecture.number))
                    .font(Theme.serif(30, .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: lecture.title)
                        .font(Theme.serif(18, .semibold))
                        .foregroundStyle(Theme.ink)
                    Group {
                        switch lecture.status {
                        case .ready:
                            Text("\(String(lecture.slideCount)) سلايد · \(String(lecture.explainedCount)) مشروحة")
                        case .preparing:
                            Text("تقدر تبدأ من السلايدات الجاهزة")
                        }
                    }
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.inkSoft)
                }
                .fixedSize()
                Leader()
                status
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var status: some View {
        switch lecture.status {
        case .ready:
            HStack(spacing: 12) {
                Text(verbatim: "\(Int(lecture.progress * 100))%")
                    .font(Theme.serif(15, .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Stamp(text: "جاهزة", size: 12, angle: -6)
            }
        case let .preparing(progress):
            VStack(alignment: .trailing, spacing: 5) {
                Text("يتجهّز " + RichText.ltr("\(Int(progress * 100))%"))
                    .font(Theme.text(12.5, .bold))
                    .foregroundStyle(Theme.inkSoft)
                ProgressTrack(value: progress, height: 7)
                    .frame(width: 84)
            }
        }
    }
}

/// «قص هنا»: the dashed line where a new lecture goes in.
private struct CutHere: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text("أضف محاضرة: استورد PDF من الملفات")
                    .font(Theme.text(14, .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize()
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
                    .overlay(
                        GeometryReader { geo in
                            Path { p in
                                p.move(to: .zero)
                                p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            }
                            .stroke(Theme.inkSoft, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                        }
                    )
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A sticky note left on the page: what you got wrong, and five minutes to fix it.
struct ReviewNote: View {
    var count: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(String(count)) توقّعات غلطت فيها")
                    .font(Theme.text(19, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("مراجعة سريعة قبل الكويز، 5 دقايق تقريبًا.")
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                HStack(spacing: 6) {
                    Text("ابدأ المراجعة")
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(Theme.text(15, .bold))
                .foregroundStyle(Theme.red)
                .overlay(alignment: .bottom) { Hairline(color: Theme.red, weight: 1.5).offset(y: 4) }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background {
                ZStack {
                    Color(hex: 0xF6DF6E)
                    LinearGradient(colors: [.clear, Theme.ink.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    Grain(density: 0.8)
                }
                .shadow(color: Theme.ink.opacity(0.2), radius: 1, y: 1)
                .shadow(color: Theme.ink.opacity(0.14), radius: 10, x: 0, y: 7)
            }
            .taped(.top, angle: 3)
            .rotationEffect(.degrees(-2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
