import MoeedCore
import SwiftUI

/// The design system on one page: palette, type, figures, the nib icons and the covers.
/// Rendered by CI in light and dark so the foundation can be checked before any screen uses it.
public struct FoundationSheet: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 30) {
                header
                typeRamp
                figures
            }
            .frame(width: 460, alignment: .leading)
            VStack(alignment: .leading, spacing: 30) {
                palette
                icons
                covers
                answers
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("الأساس · \(scheme == .dark ? "داكن" : "فاتح")")
                .font(Typeface.plex(13, .semibold))
                .foregroundStyle(Palette.accent)
            Text("مُعيد")
                .font(Typeface.plex(52, .bold))
                .foregroundStyle(Palette.text)
            Text("يشرح لك المحاضرة شريحة شريحة، بقلمه، وبصوته.")
                .font(Typeface.plex(17))
                .foregroundStyle(Palette.text2)
        }
    }

    private var typeRamp: some View {
        section("الخط · IBM Plex Sans Arabic") {
            VStack(alignment: .leading, spacing: 10) {
                ramp("عنوان كبير", 34, .bold, "34 عريض")
                ramp("عنوان القسم", 22, .semibold, "22 شبه عريض")
                ramp("نص الشرح يمشي معك كلمة كلمة", 17, .regular, "17 عادي")
                ramp("بقي 9 دقائق · الشريحة 16 من 48", 13, .medium, "13 متوسط")
                ramp("خفيف للأرقام الكبيرة", 15, .light, "15 خفيف")
                Text(RichText.attributed("عند `t = 0.3 s` تكون الموجة في القاع، و`v = 10 sin(ωt)` أقصاها 10."))
                    .font(Typeface.plex(17))
                    .foregroundStyle(Palette.text)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sinusoidal Waveforms").font(Typeface.serif(26, .bold))
                    Text("Lecture 5 · Electrical Circuits I").font(Typeface.serif(16, italic: true))
                        .foregroundStyle(Palette.text2)
                }
                .foregroundStyle(Palette.text)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var figures: some View {
        section("الأرقام") {
            HStack(alignment: .firstTextBaseline, spacing: 22) {
                stat(16.figures, "محاضرة")
                stat("0.3".figures, "ثانية")
                stat(48.figures, "شريحة")
            }
        }
    }

    private var palette: some View {
        section("الألوان") {
            let swatches: [(String, Adaptive)] = [
                ("الخلفية", Palette.bg), ("مرفوع", Palette.raised), ("مرفوع 2", Palette.raised2),
                ("نص", Palette.text), ("نص 2", Palette.text2), ("نص 3", Palette.text3),
                ("تعبئة", Palette.fill), ("فاصل", Palette.sep),
                ("الأساسي", Palette.accent), ("ناعم", Palette.accentSoft), ("الحبر", Palette.ink), ("تنبيه", Palette.alert),
            ]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 12), count: 6), alignment: .leading, spacing: 12) {
                ForEach(swatches.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(swatches[i].1)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.sep, lineWidth: 0.5))
                            .frame(height: 44)
                        Text(swatches[i].0)
                            .font(Typeface.plex(11, .medium))
                            .foregroundStyle(Palette.text2)
                    }
                }
            }
        }
    }

    private var icons: some View {
        section("أيقونات بسنّ القلم") {
            HStack(spacing: 26) {
                ForEach(NibIcon.Name.allCases, id: \.self) { name in
                    VStack(spacing: 8) {
                        NibIcon(name, size: 44, weight: 2.3)
                            .foregroundStyle(Palette.text)
                        NibIcon(name, size: 24)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
        }
    }

    private var covers: some View {
        section("الأغلفة") {
            HStack(spacing: 12) {
                ForEach(Cover.samples, id: \.self) { CoverArt($0, size: 84) }
            }
        }
    }

    private var answers: some View {
        section("الإجابة") {
            HStack(spacing: 10) {
                answer("أ", "صفر", Stage.wrongBG, Stage.wrongFG)
                answer("ب", "سالب القيمة العظمى", Stage.rightBG, Stage.rightFG)
                answer("ج", "موجب", .white.opacity(0.1), .white)
            }
            .padding(14)
            .background(Stage.deep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: Parts

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Typeface.plex(13, .semibold))
                .foregroundStyle(Palette.text2)
            content()
        }
    }

    private func ramp(_ sample: String, _ size: CGFloat, _ weight: Font.Weight, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(sample).font(Typeface.plex(size, weight)).foregroundStyle(Palette.text)
            Spacer(minLength: 12)
            Text(label).font(Typeface.plex(11, .medium)).foregroundStyle(Palette.text3)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Typeface.plex(40, .light)).foregroundStyle(Palette.text)
            Text(label).font(Typeface.plex(13, .medium)).foregroundStyle(Palette.text2)
        }
    }

    private func answer(_ letter: String, _ title: String, _ bg: Color, _ fg: Color) -> some View {
        HStack(spacing: 8) {
            Text(letter).font(Typeface.plex(13, .bold)).opacity(0.7)
            Text(title).font(Typeface.plex(15, .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
