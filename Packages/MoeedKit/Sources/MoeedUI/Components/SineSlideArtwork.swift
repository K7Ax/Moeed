import SwiftUI

/// The sample slide, drawn in its own 800 × 600 space. Stands in for a rendered PDF page
/// until import is wired up; it's our own content, not course material.
struct SineSlideArtwork: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            Text(verbatim: "Sine Wave · Reading the Graph")
                .font(.custom("Georgia-Bold", size: 34))
                .foregroundStyle(Theme.slideTitle)
                .frame(width: 800)
                .position(x: 400, y: 50)
            Path { p in
                p.move(to: CGPoint(x: 60, y: 84))
                p.addLine(to: CGPoint(x: 740, y: 84))
            }
            .stroke(Theme.slideRule, lineWidth: 2)

            leading("Find:", baseline: 134, font: "Georgia-Bold", color: Theme.slideTitle)
            leading("a) the peak value Vp", baseline: 172)
            leading("b) v at 0.3 s and 0.6 s", baseline: 206)
            leading("c) the peak-to-peak value", baseline: 240)
            leading("d) the period T", baseline: 274)
            leading("e) the frequency", baseline: 308)
            leading("Key relation", baseline: 372, font: "Georgia-Bold", color: Theme.slideTitle)
            leading("f = 1 / T", baseline: 414, size: 26, font: "Georgia-Italic")

            axes
            wave
            ticks
        }
        .frame(width: 800, height: 600)
    }

    private var axes: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 340, y: 270))
                p.addLine(to: CGPoint(x: 340, y: 540))
                p.move(to: CGPoint(x: 330, y: 400))
                p.addLine(to: CGPoint(x: 778, y: 400))
            }
            .stroke(Theme.slideAxis, lineWidth: 2.5)
            Path { p in
                p.move(to: CGPoint(x: 778, y: 400))
                p.addLine(to: CGPoint(x: 768, y: 395))
                p.addLine(to: CGPoint(x: 768, y: 405))
                p.closeSubpath()
            }
            .fill(Theme.slideAxis)
            Path { p in
                p.move(to: CGPoint(x: 340, y: 290))
                p.addLine(to: CGPoint(x: 370, y: 290))
                p.move(to: CGPoint(x: 340, y: 510))
                p.addLine(to: CGPoint(x: 430, y: 510))
            }
            .stroke(Theme.slideGuide, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
    }

    /// 3.5 cycles, 0.4 s each at 300 px/s, amplitude 110 px = 8 V.
    private var wave: some View {
        Path { p in
            p.move(to: CGPoint(x: 340, y: 400))
            for i in 0..<7 {
                let x0 = 340 + CGFloat(i) * 60
                p.addQuadCurve(
                    to: CGPoint(x: x0 + 60, y: 400),
                    control: CGPoint(x: x0 + 30, y: i.isMultiple(of: 2) ? 180 : 620)
                )
            }
        }
        .stroke(Theme.slideWave, lineWidth: 3.5)
    }

    private var ticks: some View {
        ZStack {
            centered("8 V", x: 316, baseline: 295)
            centered("−8 V", x: 312, baseline: 515)
            ForEach(Array(["0.2", "0.4", "0.6", "0.8", "1.0", "1.2", "1.4"].enumerated()), id: \.offset) { index, label in
                centered(label, x: 400 + CGFloat(index) * 60, baseline: 424)
            }
            centered("t (s)", x: 762, baseline: 448)
            centered("v", x: 352, baseline: 264)
        }
    }

    private func leading(_ text: String, baseline: CGFloat, size: CGFloat = 21, font: String = "Georgia", color: Color = Theme.slideInk) -> some View {
        Text(verbatim: text)
            .font(.custom(font, size: size))
            .foregroundStyle(color)
            .fixedSize()
            .offset(x: 56, y: baseline - size * 0.92)
    }

    private func centered(_ text: String, x: CGFloat, baseline: CGFloat) -> some View {
        Text(verbatim: text)
            .font(.custom("Georgia", size: 16))
            .foregroundStyle(Theme.slideLabel)
            .fixedSize()
            .position(x: x, y: baseline - 5)
    }
}
