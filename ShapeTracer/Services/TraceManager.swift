import SwiftUI
import Combine
import CoreHaptics

class TraceManager: ObservableObject {
    @Published var currentShape: TraceableShape?
    @Published var isTracing: Bool = false
    @Published var traceProgress: Double = 0.0
    @Published var currentPoint: CGPoint = .zero
    @Published var progress: Double = 0
    
    let audioManager = AudioManager()
    let hapticManager = HapticManager()
    private var currentPath: [CGPoint] = []
    private var isComplete: Bool = false
    private var lastAnnouncedProgress: Double = 0
    
    private var lastDirectionAnnouncement: Date = Date()
    private let directionAnnouncementCooldown: TimeInterval = 2.0
    private var lastKnownPosition: CGPoint?
    private var isOnPath: Bool = false
    
    private let pathToneFrequency: Double = 440.0  // A4 note
    private let vertexToneFrequency: Double = 880.0  // A5 note
    private let pathHapticIntensity: Float = 0.5
    private let pathHapticSharpness: Float = 0.3
    private let vertexHapticIntensity: Float = 1.0
    private let vertexHapticSharpness: Float = 0.8
    
    init() {
        print("🔊 Initializing TraceManager")
        print("📳 Haptic support available: \(CHHapticEngine.capabilitiesForHardware().supportsHaptics)")
    }
    
    func setShape(_ shape: TraceableShape) {
        currentShape = shape
    }
    
    private func provideDirectionalFeedback(for point: CGPoint) {
        guard let shape = currentShape else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastDirectionAnnouncement) >= directionAnnouncementCooldown else {
            return
        }
        
        guard let nearestPoint = findNearestPointOnPath(from: point, shape: shape) else { return }
        
        let distance = hypot(point.x - nearestPoint.x, point.y - nearestPoint.y)
        let wasOnPath = isOnPath
        isOnPath = distance <= 20
        
        // If we were on path and now we're off, provide gentle correction
        if wasOnPath && !isOnPath {
            lastDirectionAnnouncement = now
            provideContextualGuidance(from: point, to: nearestPoint, shape: shape)
            return
        }
        
        if distance > 40 {
            lastDirectionAnnouncement = now
            provideContextualGuidance(from: point, to: nearestPoint, shape: shape)
            return
        }
        
        if let cornerInfo = isNearCorner(point: point, shape: shape) {
            lastDirectionAnnouncement = now
            UIAccessibility.post(notification: .announcement, 
                               argument: "Approaching \(cornerInfo) corner")
            return
        }
    }
    
    private func provideContextualGuidance(from current: CGPoint, to target: CGPoint, shape: TraceableShape) {
        let _ = atan2(target.y - current.y, target.x - current.x)
        
        let dx = target.x - current.x
        let dy = target.y - current.y
        
        var message = ""
        
        if shape.type == .circle {
            if abs(dx) > abs(dy) {
                message = dx > 0 ? "Continue tracing clockwise" : "Continue tracing counterclockwise"
            } else {
                message = dy > 0 ? "Follow the curve downward" : "Follow the curve upward"
            }
        } else {
            if abs(dx) > abs(dy) {
                message = "Follow the \(dx > 0 ? "right" : "left") edge"
            } else {
                message = "Follow the \(dy > 0 ? "bottom" : "top") edge"
            }
        }
        
        let distance = hypot(dx, dy)
        if distance > 100 {
            message += ". You're quite far from the path"
        } else if distance > 50 {
            message += ". You're getting closer"
        }
        
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    private func isNearCorner(point: CGPoint, shape: TraceableShape) -> String? {
        guard shape.type == .square else { return nil }
        
        let cornerRadius: CGFloat = 30
        let corners = [
            (CGPoint(x: 0, y: 0), "top-left"),
            (CGPoint(x: 1, y: 0), "top-right"),
            (CGPoint(x: 1, y: 1), "bottom-right"),
            (CGPoint(x: 0, y: 1), "bottom-left")
        ]
        
        let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let inset: CGFloat = 20
        let squareRect = rect.insetBy(dx: inset, dy: inset)
        
        for (corner, name) in corners {
            let cornerPoint = CGPoint(
                x: corner.x * squareRect.width + squareRect.minX,
                y: corner.y * squareRect.height + squareRect.minY
            )
            let distance = hypot(point.x - cornerPoint.x, point.y - cornerPoint.y)
            if distance < cornerRadius {
                return name
            }
        }
        return nil
    }
    
    private func findNearestPointOnPath(from point: CGPoint, shape: TraceableShape) -> CGPoint? {
        var nearestPoint: CGPoint?
        var minDistance: CGFloat = .infinity
        
        let pathPoints: [CGPoint]
        switch shape.type {
        case .square:
            pathPoints = shape.squarePathPoints(in: CGRect(x: 0, y: 0, width: 300, height: 300))
        case .circle:
            pathPoints = shape.circlePathPoints(in: CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        
        for pathPoint in pathPoints {
            let distance = hypot(point.x - pathPoint.x, point.y - pathPoint.y)
            if distance < minDistance {
                minDistance = distance
                nearestPoint = pathPoint
            }
        }
        
        return nearestPoint
    }
    
    func provideCorrectPathFeedback() {
        print("🔊 Playing path tone at \(pathToneFrequency)Hz")
        print("📳 Playing path haptic feedback")
        audioManager.playTone(frequency: pathToneFrequency)
        hapticManager.playHaptic(intensity: pathHapticIntensity, 
                                sharpness: pathHapticSharpness)
    }
    
    func provideVertexFeedback() {
        print("🔊 Playing vertex tone at \(vertexToneFrequency)Hz")
        print("📳 Playing vertex haptic feedback")
        audioManager.playTone(frequency: vertexToneFrequency)
        hapticManager.playHaptic(intensity: vertexHapticIntensity, 
                                sharpness: vertexHapticSharpness)
    }
    
    func provideDirectionalFeedback(position: CGPoint, in rect: CGRect, shapeType: ShapeType, isOnPath: Bool) {
        let _ = position.x / rect.width
        let relativeY = position.y / rect.height
        
        // 1. Calculate distance-based volume
        let centerX = rect.width / 2
        let centerY = rect.height / 2
        let distanceFromCenter = sqrt(pow(position.x - centerX, 2) + pow(position.y - centerY, 2))
        let maxDistance = sqrt(pow(rect.width/2, 2) + pow(rect.height/2, 2))
        let volume = 1.0 - (distanceFromCenter / maxDistance) * 0.5
        
        // 2. Get shape-specific base frequency
        let baseFrequency: Double
        switch shapeType {
        case .square:
            baseFrequency = 440 // A4 note
        case .circle:
            baseFrequency = 523.25 // C5 note
        }
        
        // 3. Play main directional tone
        let pitchMultiplier = 1.0 + (0.5 - relativeY) * 0.3
        audioManager.playTone(frequency: baseFrequency * pitchMultiplier)
        
        // 4. Provide haptic feedback
        hapticManager.playHaptic(intensity: Float(volume), sharpness: 0.5)
    }
    
    func stopFeedback() {
        print("🔇 Stopping feedback")
        audioManager.stopTone()
        hapticManager.stopHaptic()
    }
}
