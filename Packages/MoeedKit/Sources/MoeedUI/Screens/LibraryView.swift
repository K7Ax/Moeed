import SwiftUI
import MoeedCore

struct LibraryView: View {
    @Environment(AppRouter.self) private var router
    private let course = Samples.course
    private let resume = Samples.resume

    init() {}

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            VStack(alignment: .leading, spacing: 26) {
                header
                continueCard
                lectures
                reviewBanner
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Theme.ground)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: course.code)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text(verbatim: course.name)
                    .font(.system(size: 30, weight: .bold))
            }
            Spacer()
            Button { router.route = .importing } label: {
                Label("استيراد محاضرة", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.filled(Theme.ink, height: 46))
        }
    }

    private var continueCard: some View {
        Button { router.route = .player } label: {
            HStack(alignment: .top, spacing: 28) {
                SlideStage(page: Samples.sinePage, marks: [.circle(center: SlidePoint(430, 510), rx: 26, ry: 26)])
                    .frame(width: 312, height: 234)
                    .slideFrame()
                    .overlay(alignment: .bottomLeading) {
                        Text("سلايد \(String(resume.page))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Theme.ink.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(10)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text("كمّل من حيث وقفت")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.pen)
                    Text(verbatim: "Lecture \(resume.lecture.number) · \(resume.lecture.title)")
                        .font(.system(size: 25, weight: .bold))
                    Text("السلايد \(String(resume.page)) من \(String(resume.lecture.slideCount)) · الخطوة \(String(resume.step)) من \(String(resume.stepCount)): \(resume.stepTitle)")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 12) {
                        ProgressTrack(value: resume.lecture.progress)
                        Text(verbatim: "\(Int(resume.lecture.progress * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 6)
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Text("كمّل الشرح")
                            Image(systemName: "chevron.forward")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(Theme.pen, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        Text("\(String(resume.askCount)) أسئلة توقّع في هالمحاضرة")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var lectures: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("المحاضرات")
                .font(.system(size: 17, weight: .bold))
            HStack(alignment: .top, spacing: 16) {
                ForEach(course.lectures) { lecture in
                    LectureTile(lecture: lecture) {
                        router.route = lecture.status == .ready ? .player : .importing
                    }
                }
                Button { router.route = .importing } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                        Text("استورد PDF من الملفات")
                            .font(.system(size: 14.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Theme.faint, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reviewBanner: some View {
        Button { router.route = .review } label: {
            HStack(spacing: 16) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.highlighter)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(Samples.reviewItems.count + 2)) توقّعات غلطت فيها")
                        .font(.system(size: 15.5, weight: .semibold))
                    Text("مراجعة سريعة قبل الكويز: 5 دقايق تقريبًا")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.onDark)
                }
                Spacer()
                Text("ابدأ المراجعة")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.highlighter)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LectureTile: View {
    var lecture: Lecture
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(verbatim: "Lecture \(lecture.number)")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    switch lecture.status {
                    case .ready:
                        StatusPill(text: "جاهزة", foreground: Theme.correctText, background: Theme.correctTint)
                    case let .preparing(progress):
                        StatusPill(text: "يتجهّز \(Int(progress * 100))%", foreground: Theme.workingText, background: Theme.workingTint)
                    }
                }
                Group {
                    switch lecture.status {
                    case .ready:
                        Text("\(String(lecture.slideCount)) سلايد · \(String(lecture.explainedCount)) مشروحة")
                    case .preparing:
                        Text("تقدر تبدأ من السلايدات الجاهزة")
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                switch lecture.status {
                case .ready:
                    ProgressTrack(value: lecture.progress, tint: Theme.ink, height: 6)
                case let .preparing(progress):
                    ProgressTrack(value: progress, tint: Theme.working, height: 6)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
