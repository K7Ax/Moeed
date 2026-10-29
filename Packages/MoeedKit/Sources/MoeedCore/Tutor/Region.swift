import Foundation

/// A part of the slide the tutor can point at. The model only ever names regions by id;
/// the app owns the geometry, so ink can't land on something that isn't on the page.
public struct Region: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text, equation, figure

        var letter: String {
            switch self {
            case .text: "T"
            case .equation: "E"
            case .figure: "F"
            }
        }
    }

    public var id: String
    public var kind: Kind
    public var box: SlideRect
    public var text: String
    public var isTitle: Bool
    /// The figure this region sits inside, like an axis label inside a graph.
    public var host: String?

    public init(id: String, kind: Kind, box: SlideRect, text: String = "", isTitle: Bool = false, host: String? = nil) {
        self.id = id
        self.kind = kind
        self.box = box
        self.text = text
        self.isTitle = isTitle
        self.host = host
    }
}

/// Everything on one slide the tutor can refer to, in slide space (top-left origin).
public struct RegionMap: Hashable, Codable, Sendable {
    /// Figures are split into a 10 × 10 grid so the model can name a point inside them: `F1@2.5,8`.
    public static let grid = 10.0

    public var width: Double
    public var height: Double
    public var regions: [Region]

    public init(width: Double, height: Double, regions: [Region]) {
        self.width = width
        self.height = height
        self.regions = regions
    }

    public var bounds: SlideRect { SlideRect(0, 0, width, height) }
    public var ids: Set<String> { Set(regions.map(\.id)) }

    public subscript(id: String) -> Region? {
        regions.first { $0.id == id }
    }

    public var title: String? {
        regions.first(where: \.isTitle)?.text
    }

    /// The compact listing the model reads next to the marked-up slide image.
    public var listing: String {
        regions.map { region in
            var tags = [region.isTitle ? "title" : region.kind.rawValue]
            if let host = region.host { tags.append("in \(host)") }
            if region.kind == .figure {
                tags.append("10×10 grid")
                return "\(region.id) [\(tags.joined(separator: ", "))]"
            }
            let text = region.text.count > 90 ? String(region.text.prefix(90)) + "…" : region.text
            return "\(region.id) [\(tags.joined(separator: ", "))] \"\(text)\""
        }
        .joined(separator: "\n")
    }
}
