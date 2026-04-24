import Foundation
import AppKit

// MARK: - Drawing Engine — Stroke smoothing and rendering

class DrawingEngine {

    /// Catmull-Rom spline smoothing for pen strokes
    static func smoothedPath(from points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 1..<points.count - 1 {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[min(points.count - 1, i + 1)]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p2.x - p0.x) / 6,
                y: p2.y - (p2.y - p0.y) / 6
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }

    /// Simulate pressure based on velocity (distance between consecutive points)
    static func widthForVelocity(p1: CGPoint, p2: CGPoint, baseWidth: CGFloat) -> CGFloat {
        let distance = hypot(p2.x - p1.x, p2.y - p1.y)
        let velocityFactor = min(max(1.0 - distance / 100.0, 0.5), 1.2)
        return baseWidth * velocityFactor
    }
}
