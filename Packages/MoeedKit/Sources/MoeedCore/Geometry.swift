import Foundation

/// A point in slide space: the page's own units (the sample slide is 800 × 600).
public struct SlidePoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// A rectangle in slide space.
public struct SlideRect: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var midX: Double { x + w / 2 }
    public var midY: Double { y + h / 2 }

    public func contains(_ r: SlideRect) -> Bool {
        r.x >= x && r.y >= y && r.maxX <= maxX && r.maxY <= maxY
    }

    /// The point on (or inside) this rectangle closest to `p`. Used to start caption leader lines.
    public func clamped(_ p: SlidePoint) -> SlidePoint {
        SlidePoint(min(max(p.x, x), maxX), min(max(p.y, y), maxY))
    }
}
