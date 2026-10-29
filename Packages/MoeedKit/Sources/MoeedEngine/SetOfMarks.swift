import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import MoeedCore

/// The slide as the model sees it: every region boxed and tagged with its id, and a numbered
/// 10 × 10 grid inside each figure. The model reads ids and grid points off this picture.
public enum SetOfMarks {
    public static func draw(_ slide: GroundedSlide) -> CGImage? {
        let image = slide.image
        let width = image.width
        let height = image.height
        let scale = CGFloat(width) / CGFloat(slide.map.width)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.textMatrix = .identity

        // Figures first, so text tags inside them stay readable on top.
        let regions = slide.map.regions.sorted { ($0.kind == .figure ? 0 : 1) < ($1.kind == .figure ? 0 : 1) }
        for region in regions {
            let color = color(for: region.kind)
            // Slide space runs down; the bitmap context runs up.
            let rect = CGRect(
                x: CGFloat(region.box.x) * scale,
                y: CGFloat(height) - CGFloat(region.box.maxY) * scale,
                width: CGFloat(region.box.w) * scale,
                height: CGFloat(region.box.h) * scale
            )
            if region.kind == .figure { grid(in: rect, color: color, context: context) }
            context.setStrokeColor(color)
            context.setLineWidth(3)
            context.stroke(rect)
            tag(region.id, at: rect, color: color, imageHeight: CGFloat(height), context: context)
        }
        return context.makeImage()
    }

    static func color(for kind: Region.Kind) -> CGColor {
        switch kind {
        case .text: CGColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
        case .equation: CGColor(red: 0.85, green: 0.27, blue: 0.94, alpha: 1)
        case .figure: CGColor(red: 0.09, green: 0.64, blue: 0.29, alpha: 1)
        }
    }

    private static func grid(in rect: CGRect, color: CGColor, context: CGContext) {
        let steps = Int(RegionMap.grid)
        context.setStrokeColor(color.copy(alpha: 0.28) ?? color)
        context.setLineWidth(1)
        for k in 1..<steps {
            let x = rect.minX + rect.width * CGFloat(k) / CGFloat(steps)
            let y = rect.maxY - rect.height * CGFloat(k) / CGFloat(steps)
            context.strokeLineSegments(between: [CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY)])
            context.strokeLineSegments(between: [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)])
        }
        // Column numbers along the top edge, row numbers down the left, counted from the top-left.
        for k in 0..<steps {
            let cx = rect.minX + rect.width * (CGFloat(k) + 0.5) / CGFloat(steps)
            let cy = rect.maxY - rect.height * (CGFloat(k) + 0.5) / CGFloat(steps)
            text("\(k)", at: CGPoint(x: cx - 4, y: rect.maxY - 16), size: 14, color: color, context: context)
            text("\(k)", at: CGPoint(x: rect.minX + 4, y: cy - 5), size: 14, color: color, context: context)
        }
    }

    private static func tag(_ id: String, at rect: CGRect, color: CGColor, imageHeight: CGFloat, context: CGContext) {
        let size: CGFloat = 20
        let width = measure(id, size: size) + 10
        // Above the box's top-left corner, or just inside it when there's no room above.
        let top = rect.maxY + 24 <= imageHeight ? rect.maxY : rect.maxY - 24
        let label = CGRect(x: rect.minX, y: top, width: width, height: 24)
        context.setFillColor(color.copy(alpha: 0.92) ?? color)
        context.fill(label)
        text(id, at: CGPoint(x: label.minX + 5, y: label.minY + 5), size: size, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), context: context)
    }

    private static func line(_ string: String, size: CGFloat, color: CGColor) -> CTLine {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    }

    private static func measure(_ string: String, size: CGFloat) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(string, size: size, color: CGColor(gray: 0, alpha: 1)), nil, nil, nil))
    }

    private static func text(_ string: String, at point: CGPoint, size: CGFloat, color: CGColor, context: CGContext) {
        context.textPosition = point
        CTLineDraw(line(string, size: size, color: color), context)
    }
}

public extension CGImage {
    func pngData() -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, self, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
