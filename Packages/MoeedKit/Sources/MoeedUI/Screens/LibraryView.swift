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
            VStack(alignment: .leading, spacing: 20) {
                hero
                continueCard
                lectures
                reviewBanner
            }
            .padding(.horizontal, 36)
            .padding(.top, 30)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Aurora())
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(verbatim: course.code)
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Theme.mint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.teal.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.mint.opacity(0.35), lineWidth: 1))
                    Spacer()
                    Button { router.route = .importing } label: {
                        Label("استيراد محاضرة", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.outline(height: 40))
                }
                Text(verbatim: course.name)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.white, Theme.mint], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.teal.opacity(0.5), radius: 18)
                Text("محاضرة جاهزة تنتظرك، و\(String(Samples.reviewItems.count + 2)) توقّعات تستاهل نظرة ثانية.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondary)
                HStack(spacing: 10) {
                    Stat(value: RichText.ltr("\(Int(resume.lecture.progress * 100))%"), label: "من المحاضرة", tint: Theme.mint)
                    Stat(value: String(course.lectures.count), label: "محاضرات", tint: Theme.ocean)
                    Stat(value: String(Samples.reviewItems.count + 2), label: "للمراجعة", tint: Theme.pen)
                }
                .padding(.top, 4)
            }
            .padding(.leading, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)

            LogoSculpture()
                .frame(width: 380, height: 330)
                .padding(.vertical, -36)
                .padding(.trailing, 4)
        }
        .frame(height: 262)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                    .fill(Theme.surface.opacity(0.75))
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                    .fill(EllipticalGradient(colors: [Theme.teal.opacity(0.35), .clear],
                                             center: UnitPoint(x: 0.15, y: 0.6), startRadiusFraction: 0, endRadiusFraction: 0.6))
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                    .strokeBorder(Theme.edge, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
        }
    }

    // MARK: Continue

    private var continueCard: some View {
        Button { router.route = .player } label: {
            HStack(alignment: .center, spacing: 26) {
                SlideStage(page: Samples.sinePage, marks: [.circle(center: SlidePoint(430, 510), rx: 26, ry: 26)])
                    .frame(width: 216, height: 162)
                    .slideFrame()
                    .rotation3DEffect(.degrees(-16), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    .overlay(alignment: .bottomLeading) {
                        Text("سلايد \(String(resume.page))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Theme.pen, in: Capsule())
                            .glow(Theme.pen, radius: 8)
                            .offset(x: -6, y: 8)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("كمّل من حيث وقفت")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.pen)
                    Text(verbatim: "Lecture \(resume.lecture.number) · \(resume.lecture.title)")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text("السلايد \(String(resume.page)) من \(String(resume.lecture.slideCount)) · الخطوة \(String(resume.step)) من \(String(resume.stepCount)): \(resume.stepTitle)")
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        ProgressTrack(value: resume.lecture.progress)
                        Text(verbatim: "\(Int(resume.lecture.progress * 100))%")
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.mint)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("كمّل الشرح")
                        Image(systemName: "play.fill")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onBright)
                    .padding(.horizontal, 24)
                    .frame(height: 52)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        shape.fill(Theme.brand)
                            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center)))
                            .glow(Theme.teal, radius: 18, opacity: 0.6)
                    }
                    Text("\(String(resume.askCount)) أسئلة توقّع")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: Radius.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: Lectures

    private var lectures: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("المحاضرات")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .top, spacing: 14) {
                ForEach(course.lectures) { lecture in
                    LectureTile(lecture: lecture) {
                        router.route = lecture.status == .ready ? .player : .importing
                    }
                }
                Button { router.route = .importing } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.mint)
                            .frame(width: 38, height: 38)
                            .background(Theme.teal.opacity(0.16), in: Circle())
                        Text("استورد PDF من الملفات")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Theme.mint.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Review

    private var reviewBanner: some View {
        Button { router.route = .review } label: {
            HStack(spacing: 16) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.sunset, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .glow(Theme.pen, radius: 14, opacity: 0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(Samples.reviewItems.count + 2)) توقّعات غلطت فيها")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("مراجعة سريعة قبل الكويز: 5 دقايق تقريبًا")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("ابدأ المراجعة")
                    Image(systemName: "chevron.forward")
                }
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(Theme.pen)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                shape.fill(Theme.surface.opacity(0.9))
                    .overlay(shape.fill(LinearGradient(colors: [Theme.pen.opacity(0.22), .clear], startPoint: .leading, endPoint: .center)))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [Theme.pen.opacity(0.6), .white.opacity(0.06)], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
}

/// A number with a coloured dot and a word: "62% من المحاضرة".
private struct Stat: View {
    var value: String
    var label: LocalizedStringKey
    var tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(tint).frame(width: 7, height: 7).glow(tint, radius: 5, opacity: 0.9)
            Text(verbatim: value)
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
    }
}

private struct LectureTile: View {
    var lecture: Lecture
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(verbatim: "Lecture \(lecture.number)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        switch lecture.status {
                        case .ready:
                            StatusPill(text: "جاهزة", foreground: Theme.correctText, background: Theme.correctTint)
                        case let .preparing(progress):
                            StatusPill(text: "يتجهّز " + RichText.ltr("\(Int(progress * 100))%"), foreground: Theme.workingText, background: Theme.workingTint)
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
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(radius: Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var value: Double {
        switch lecture.status {
        case .ready: return lecture.progress
        case let .preparing(progress): return progress
        }
    }

    private var tint: Color {
        lecture.status == .ready ? Theme.mint : Theme.working
    }

    /// A glowing progress ring, lit from the top.
    private var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(colors: lecture.status == .ready ? [Theme.ocean, Theme.teal, Theme.mint] : [Theme.pen, Theme.working],
                                    center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * value)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .glow(tint, radius: 6, opacity: 0.7)
            Text(verbatim: String(lecture.number))
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
        }
        .frame(width: 52, height: 52)
        .environment(\.layoutDirection, .leftToRight)
    }
}
