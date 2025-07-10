import SwiftUI


enum ShapeType: String, CaseIterable {
    case square = "Square"
    case circle = "Circle"

    var accessibilityLabel: String {
        switch self {
        case .square:
            return "Square shape with 4 corners"
        case .circle:
            return "Circle shape with smooth curves"
        }
    }
}

protocol TraceablePath {
    func path(in rect: CGRect) -> Path 
    func normalizedPath(in rect: CGRect) -> Path
    func isPoint(_ point: CGPoint, nearPath path: [CGPoint], tolerance: CGFloat) -> Bool
    func nearestVertex(to point: CGPoint, in rect: CGRect) -> CGPoint?
}

struct TraceableShape: TraceablePath {
    let type: ShapeType
    private let pathResolution: Int = 100 

    func path(in rect: CGRect) -> Path {
        switch type {
        case .square:
            return Path { path in
                let inset: CGFloat = 20
                let squareRect = rect.insetBy(dx: inset, dy: inset)
                path.addRect(squareRect)
            }
        case .circle:
            return Path { path in
                let inset: CGFloat = 20
                let circleRect = rect.insetBy(dx: inset, dy: inset)
                path.addEllipse(in: circleRect)
            }
        }
    }

    func normalizedPath(in rect: CGRect) -> Path {
        switch type {
        case .square:
            return Path { path in
                let points = squarePathPoints(in: rect)
                if let first = points.first {
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
        case .circle:
            return Path { path in
                let points = circlePathPoints(in: rect)
                if let first = points.first {
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
        }
    }

    func squarePathPoints(in rect: CGRect) -> [CGPoint] {
        let inset: CGFloat = 20
        let squareRect = rect.insetBy(dx: inset, dy: inset)
        var points: [CGPoint] = []

        let perSide = pathResolution / 4

        for i in 0...perSide {
            let x = squareRect.minX + (squareRect.width * CGFloat(i) / CGFloat(perSide))
            points.append(CGPoint(x: x, y: squareRect.minY))
        }

        for i in 0...perSide {
            let y = squareRect.minY + (squareRect.height * CGFloat(i) / CGFloat(perSide))
            points.append(CGPoint(x: squareRect.maxX, y: y))
        }

        for i in 0...perSide {
            let x = squareRect.maxX - (squareRect.width * CGFloat(i) / CGFloat(perSide))
            points.append(CGPoint(x: x, y: squareRect.maxY))
        }

        for i in 0...perSide {
            let y = squareRect.maxY - (squareRect.height * CGFloat(i) / CGFloat(perSide))
            points.append(CGPoint(x: squareRect.minX, y: y))
        }

        return points
    }

    func circlePathPoints(in rect: CGRect) -> [CGPoint] {
        let inset: CGFloat = 20
        let circleRect = rect.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
        let radius = min(circleRect.width, circleRect.height) / 2
        var points: [CGPoint] = []

        for i in 0...pathResolution {
            let angle = (CGFloat(i) / CGFloat(pathResolution)) * 2 * .pi 
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    func isPoint(_ point: CGPoint, nearPath pathPoints: [CGPoint], tolerance: CGFloat) -> Bool {
        for pathPoint in pathPoints {
            let distance = hypot(point.x - pathPoint.x, point.y - pathPoint.y)
            if distance <= tolerance {
                return true
            }
        }
        return false
    }
    
    func nearestVertex(to point: CGPoint, in rect: CGRect) -> CGPoint? {
        guard type == .square else { return nil }

        let inset: CGFloat = 20
        let squareRect = rect.insetBy(dx: inset, dy: inset) 

        let vertices = [
            CGPoint(x: squareRect.minX, y: squareRect.minY),
            CGPoint(x: squareRect.maxX, y: squareRect.minY),
            CGPoint(x: squareRect.maxX, y: squareRect.maxY),
            CGPoint(x: squareRect.minX, y: squareRect.maxY)
        ]

        let vertexThreshold: CGFloat = 30

        for vertex in vertices {
            let distance = hypot(point.x - vertex.x, point.y - vertex.y)
            if distance <= vertexThreshold {
                return vertex
            }
        }

        return nil
    }
}
