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

public extension SlideRect {
    var area: Double { w * h }
    var center: SlidePoint { SlidePoint(midX, midY) }

    func contains(_ p: SlidePoint) -> Bool {
        p.x >= x && p.x <= maxX && p.y >= y && p.y <= maxY
    }

    func union(_ r: SlideRect) -> SlideRect {
        let left = min(x, r.x)
        let top = min(y, r.y)
        return SlideRect(left, top, max(maxX, r.maxX) - left, max(maxY, r.maxY) - top)
    }

    /// Grows (positive) or shrinks (negative) the rectangle on every side.
    func outset(_ d: Double) -> SlideRect {
        SlideRect(x - d, y - d, w + 2 * d, h + 2 * d)
    }

    func overlap(_ r: SlideRect) -> Double {
        let ow = min(maxX, r.maxX) - max(x, r.x)
        let oh = min(maxY, r.maxY) - max(y, r.y)
        return ow > 0 && oh > 0 ? ow * oh : 0
    }

    /// True when the rectangles touch or come within `dx` across and `dy` down of each other.
    func near(_ r: SlideRect, dx: Double, dy: Double) -> Bool {
        !(maxX + dx < r.x || r.maxX + dx < x || maxY + dy < r.y || r.maxY + dy < y)
    }

    /// The same rectangle moved (not resized, unless it's too big) so it sits inside `bounds`.
    func kept(in bounds: SlideRect) -> SlideRect {
        let nw = min(w, bounds.w)
        let nh = min(h, bounds.h)
        return SlideRect(min(max(x, bounds.x), bounds.maxX - nw), min(max(y, bounds.y), bounds.maxY - nh), nw, nh)
    }
}
