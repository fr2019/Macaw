import Foundation

extension Locus {

    internal func arcToPath(_ arc: Arc) -> Path {
        let rx = arc.ellipse.rx
        let ry = arc.ellipse.ry
        let cx = arc.ellipse.cx
        let cy = arc.ellipse.cy

        var delta = arc.extent
        if arc.shift == 0.0 && abs(arc.extent - .pi * 2.0) < 0.00001 {
            delta = .pi * 2.0 - 0.001
        }
        let theta1 = arc.shift

        let theta2 = theta1 + delta

        let x1 = cx + rx * cos(theta1)
        let y1 = cy + ry * sin(theta1)

        let x2 = cx + rx * cos(theta2)
        let y2 = cy + ry * sin(theta2)

        let largeArcFlag = abs(delta) > .pi ? true : false
        let sweepFlag = delta > 0.0 ? true : false

        return PathBuilder(segment: PathSegment(type: .M, data: [x1, y1])).A(rx, ry, 0.0, largeArcFlag, sweepFlag, x2, y2).build()
    }

    internal func pointToPath(_ point: Point) -> Path {
        return MoveTo(x: point.x, y: point.y).lineTo(x: point.x, y: point.y).build()
    }

    internal func pointsToPath(_ points: [Double], close: Bool = false) -> Path {
        var pb = PathBuilder(segment: PathSegment(type: .M, data: [points[0], points[1]]))
        if points.count > 2 {
            let parts = stride(from: 2, to: points.count, by: 2).map { Array(points[$0 ..< $0 + 2]) }
            for part in parts {
                pb = pb.lineTo(x: part[0], y: part[1])
            }
        }
        if close {
            pb = pb.close()
        }
        return pb.build()
    }
}
