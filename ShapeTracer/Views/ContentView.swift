import SwiftUI

struct ContentView: View {
    @StateObject private var traceManager = TraceManager()
    @State private var selectedShape: ShapeType = .square

    
    @State private var currentTouch: CGPoint?
    @State private var tracedPath: [CGPoint] = []
    @State private var isOnCorrectPath = false
    @State private var lastFeedbackTime = Date()
    @State private var lastHapticTime = Date()
    @State private var lastCornerAnnouncementTime = Date()
    @State private var lastAnnouncedCorner: CGPoint?
    @State private var hasStartedTracing = false
    @State private var lastOutOfCanvasAnnouncementTime = Date()
    @State private var isCurrentlyOutOfCanvas = false
    @State private var hasAnnouncedTracingStarted = false
    @State private var lastOffPathFeedbackTime = Date()
    @State private var isCurrentlyOffPath = false
    @State private var wasOnPathLastFrame = true
    @State private var lastSpatialGuidanceTime = Date()
    @State private var lastAnnouncedLocation = ""
    @State private var traceProgress: Double = 0.0
    @State private var hasAnnouncedStartInstruction = false
    @State private var tracedPathCoverage: Set<Int> = [] // Track which parts of the path have been traced
    @State private var lastProgressAnnouncement = 0
    @State private var isOutOfCanvas = false
    @State private var completionTime: Date?
    @State private var hasCompletedShape = false
    @State private var isTraceComplete = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityInvertColors) private var invertColors
    @Environment(\.colorScheme) private var colorScheme
    

    
    private let pathTolerance: CGFloat = 40 // Mercy buffer zone around path
    private let proximityRadius: CGFloat = 80
    private let startProximityRadius: CGFloat = 50
    private let feedbackInterval: TimeInterval = 0.2
    private let hapticInterval: TimeInterval = 0.15
    private let cornerDetectionRadius: CGFloat = 30
    private let cornerAnnouncementCooldown: TimeInterval = 3.0 // Prevent overwhelming users
    private let outOfCanvasCooldown: TimeInterval = 5.0
    private let spatialGuidanceCooldown: TimeInterval = 2.0 // Prevent overwhelming users
    private let offPathFeedbackCooldown: TimeInterval = 3.0
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 24) {
                headerText
                ShapeSelectionView(selectedShape: $selectedShape)
                tracingCanvasArea
                instructionsSection
            }
            .padding(.top)
        }
        .onAppear {
            print("📱 ContentView appeared")
        }
    }
    
    private var backgroundGradient: some View {
        Group {
            if reduceTransparency {
                Color(UIColor.systemBackground)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
    
    private var headerText: some View {
        Text("Shape Tracer")
            .font(.largeTitle)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .foregroundColor(.primary)
            .accessibilityHidden(true) // Hide from VoiceOver since app name is already announced
    }

    
    private var tracingCanvasArea: some View {
        tracingCanvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(canvasBackground)
            .padding(.horizontal)
            .onChange(of: selectedShape) {
                resetProgress()
                print("📱 Shape changed - progress reset")
            }
    }
    
    private var canvasBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(UIColor.systemBackground))
            .shadow(
                color: reduceTransparency ? Color.clear : Color.black.opacity(0.1),
                radius: reduceTransparency ? 0 : 10,
                x: 0,
                y: reduceTransparency ? 0 : 5
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
                    .opacity(reduceTransparency ? 1 : 0) // Add border for accessibility
            )
    }
    
    private var instructionsSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text("Touch and drag in the area above to trace the \(selectedShape.rawValue.lowercased())")
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .padding(.bottom)
    }
    
    private var tracingCanvas: some View {
        GeometryReader { geometry in
            let canvasSize = min(geometry.size.width, geometry.size.height) * 0.7
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            tracingCanvasContent(canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        }
    }
    
    private func tracingCanvasContent(canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        ZStack {
            shapeOutline(canvasSize: canvasSize, centerX: centerX, centerY: centerY)
            tracedPathView
            touchIndicator
            debugInfoView
            
            // Completion overlay
            if isTraceComplete {
                completionOverlay
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tracing canvas for \(selectedShape.rawValue)")
        .accessibilityHint(isTraceComplete ? "Shape completed! Double tap to start over" : accessibilityHintText)
        .accessibilityValue(currentTouch != nil ? "Currently tracing" : (isTraceComplete ? "Completed" : "Ready to trace"))
        .accessibilityAction(.default) {
            if isTraceComplete {
                resetProgress()
            } else {
                handleAccessibilityTap()
            }
        }
        .gesture(isTraceComplete ? nil : tracingGesture(canvasSize: canvasSize, centerX: centerX, centerY: centerY))
        .onAppear {
            print("📱 Direct tracing area appeared for \(selectedShape.rawValue)")
            print("📱 Canvas size: (\(Int(canvasSize))), Center: (\(Int(centerX)), \(Int(centerY)))")
        }
    }
    
    private func shapeOutline(canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        Group {
            if selectedShape == .square {
                Rectangle()
                    .stroke(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 15, lineCap: .round, dash: [10, 5]))
                    .frame(width: canvasSize, height: canvasSize)
                    .position(x: centerX, y: centerY)
            } else {
                Circle()
                    .stroke(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 15, lineCap: .round, dash: [10, 5]))
                    .frame(width: canvasSize, height: canvasSize)
                    .position(x: centerX, y: centerY)
            }
        }
    }
    

    
    private var tracedPathView: some View {
        Path { path in
            guard !tracedPath.isEmpty else { return }
            path.move(to: tracedPath[0])
            for point in tracedPath.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(Color.green, lineWidth: 5)
    }
    
    private var touchIndicator: some View {
        Group {
            if let touch = currentTouch, !isTraceComplete {
                ZStack {
                    Circle()
                        .fill(isOnCorrectPath ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                        .frame(width: 20, height: 20)
                    
                    if differentiateWithoutColor {
                        Image(systemName: isOnCorrectPath ? "checkmark" : "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .position(touch)
                .accessibilityHidden(true)
            }
        }
    }
    
    private var debugInfoView: some View {
        VStack {
            Spacer()
            VStack(spacing: 4) {
                if let touch = currentTouch {
                    Text("Touch: (\(Int(touch.x)), \(Int(touch.y)))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                if !tracedPath.isEmpty {
                    Text("Traced: \(tracedPath.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                if traceProgress > 0 && (currentTouch != nil || tracedPath.count > 0) {
                    progressIndicatorView
                }
            }
            .padding(.bottom, 10)
        }
    }
    
    private var progressIndicatorView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("X: \(Int(currentTouch?.x ?? 0))")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                Text("Y: \(Int(currentTouch?.y ?? 0))")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            
                            Text("Progress: \(Int(traceProgress * 100))% (\(tracedPathCoverage.count)/\(getPathSegmentCount()) path segments)")
                    .foregroundColor(isTraceComplete ? .green : .primary)
                    .font(.footnote)
                    .fontWeight(.medium)
        }
    }
    
    private var accessibilityHintText: String {
        hasStartedTracing ?
        "Drag your finger around the shape outline. You will hear tones and feel vibrations when on the correct path." :
        "Double tap to start tracing, then drag your finger around the shape outline."
    }
    
    private func handleAccessibilityTap() {
        if !hasStartedTracing {
            // Stop any previous ongoing feedback immediately
            traceManager.stopFeedback()
            
            hasStartedTracing = true
            if UIAccessibility.isVoiceOverRunning && !hasAnnouncedTracingStarted {
                hasAnnouncedTracingStarted = true
                UIAccessibility.post(notification: .announcement, argument: "Tracing started")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !hasAnnouncedStartInstruction {
                        hasAnnouncedStartInstruction = true
                        let instruction = getStartInstruction()
                        UIAccessibility.post(notification: .announcement, argument: instruction)
                        
                        traceManager.hapticManager.playHaptic(intensity: 0.5, sharpness: 0.3)
                        print("📳 Start point haptic pulse")
                    }
                }
            }
        }
    }
    
    private func tracingGesture(canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                currentTouch = value.location
                
                // Guide user to start point first, then announce tracing started
                if !hasStartedTracing {
                    let startPoint = getStartPoint(canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                    let distanceToStart = distance(from: value.location, to: startPoint)
                    
                    if distanceToStart <= startProximityRadius {
                        // Close enough to start point - begin tracing
                        traceManager.stopFeedback() // Stop any previous long feedback
                        hasStartedTracing = true
                        if UIAccessibility.isVoiceOverRunning && !hasAnnouncedTracingStarted {
                            hasAnnouncedTracingStarted = true
                            UIAccessibility.post(notification: .announcement, argument: "Tracing started! Follow the path.")
                        }
                    } else {
                        // Provide guidance about free exploration
                        if !hasAnnouncedStartInstruction {
                            UIAccessibility.post(notification: .announcement, argument: "Tracing ready. Move your finger around to explore. You'll hear beeps and feel vibrations when you find the correct path.")
                            hasAnnouncedStartInstruction = true
                        }
                        // Allow free exploration - don't require exact start point
                        traceManager.stopFeedback() // Stop any previous long feedback
                        hasStartedTracing = true
                        if UIAccessibility.isVoiceOverRunning && !hasAnnouncedTracingStarted {
                            hasAnnouncedTracingStarted = true
                            UIAccessibility.post(notification: .announcement, argument: "Tracing started! Explore to find the path.")
                        }
                    }
                }
                
                // If user starts tracing again after completion, reset the completion state
                if hasCompletedShape {
                    hasCompletedShape = false
                    completionTime = nil
                }
                
                // Only add to traced path if within canvas bounds (let them explore!)
                if isPointWithinCanvas(value.location, canvasSize: canvasSize, centerX: centerX, centerY: centerY) {
                    tracedPath.append(value.location)
                    // Update progress tracking
                    updateProgress(currentPoint: value.location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                }
                
                // Check if user is out of canvas area and provide guidance
                checkAndAnnounceOutOfCanvas(value.location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                
                // Only provide path feedback when within canvas bounds
                let isWithinCanvas = isPointWithinCanvas(value.location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                
                if isWithinCanvas {
                    handleCanvasInteraction(at: value.location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                } else {
                    // Outside canvas - stop any path-related feedback
                    isOnCorrectPath = false
                    traceManager.stopFeedback()
                }
                
                print("📱 Touch at: (\(Int(value.location.x)), \(Int(value.location.y))) - On path: \(isOnCorrectPath) - Path: \(tracedPath.count) points")
            }
            .onEnded { _ in
                // Don't process gesture end if shape is already complete
                guard !isTraceComplete else { return }
                
                currentTouch = nil
                isOnCorrectPath = false
                isCurrentlyOffPath = false
                traceManager.stopFeedback()
                print("📱 Touch ended - Total traced: \(tracedPath.count) points")
                
                // Check for auto-reset if shape was completed
                if hasCompletedShape, let completion = completionTime {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        // Only reset if they haven't started tracing again
                        if currentTouch == nil && Date().timeIntervalSince(completion) >= 5.0 {
                            resetProgress()
                            print("🔄 Auto-reset progress after completion")
                        }
                    }
                } else if traceProgress > 0 && !isTraceComplete {
                    // Auto-reset progress if user stops tracing for 5 seconds (for incomplete traces)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if currentTouch == nil && traceProgress > 0 && !isTraceComplete {
                            // Use the full resetProgress() function instead of partial reset
                            resetProgress()
                            print("🔄 Auto-reset: COMPLETE reset after 5 seconds of inactivity")
                        }
                    }
                }
                
                // Clear traced path after a delay (only if not completed)
                // If completed, keep the path visible so user can see their final result
                if !isTraceComplete {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            tracedPath = []
                            // Also reset progress when path is cleared (no more dot visible)
                            if tracedPathCoverage.count > 0 && !hasStartedTracing {
                                tracedPathCoverage.removeAll()
                                traceProgress = 0.0
                                print("📊 Progress reset - no active tracing")
                            }
                        }
                        print("📱 Path cleared")
                    }
                }
            }
    }
    
    private func handleCanvasInteraction(at location: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        let now = Date()
        isOnCorrectPath = isPointOnCorrectPath(location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        
        if isOnCorrectPath {
            // === ON THE ACTUAL PATH - Positive Feedback ===
            
            // Provide positive feedback when on correct path
            if now.timeIntervalSince(lastFeedbackTime) >= feedbackInterval {
                traceManager.provideCorrectPathFeedback()
                lastFeedbackTime = now
            }
            
            // Provide gentle haptic feedback when on correct path
            if now.timeIntervalSince(lastHapticTime) >= hapticInterval {
                lastHapticTime = now
                
                // Check if we're near a corner for special haptic feedback
                                        if selectedShape == .square && isNearSquareCorner(location, canvasSize: canvasSize, centerX: centerX, centerY: centerY) {
                    traceManager.hapticManager.playHaptic(intensity: 1.0, sharpness: 1.0)
                    // Double haptic for corners to make it super obvious
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        traceManager.hapticManager.playHaptic(intensity: 1.0, sharpness: 1.0)
                    }
                    print("📳 DOUBLE CORNER haptic feedback")
                    
                    if UIAccessibility.isVoiceOverRunning {
                        announceCornerWithCooldown(at: location)
                    }
                } else {
                    traceManager.hapticManager.playHaptic(intensity: 0.15, sharpness: 0.2)
                    print("📳 Gentle on-path haptic feedback")
                }
            }
            
        } else {
            if isPointNearPath(location, canvasSize: canvasSize, centerX: centerX, centerY: centerY) {
                if now.timeIntervalSince(lastSpatialGuidanceTime) >= spatialGuidanceCooldown {
                    provideSpatialGuidance(for: location, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
                    lastSpatialGuidanceTime = now
                }
                
                // Less frequent haptic for proximity
                if now.timeIntervalSince(lastHapticTime) >= hapticInterval * 2 {
                    traceManager.hapticManager.playHaptic(intensity: 0.2, sharpness: 0.2)
                    lastHapticTime = now
                    print("📳 Proximity haptic feedback")
                }
            }
            
            // Stop positive audio feedback when not on path (but no negative feedback!)
            traceManager.stopFeedback()
        }
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return hypot(point2.x - point1.x, point2.y - point1.y)
    }
    
    private func isPointWithinCanvas(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        let halfSize = canvasSize / 2
        let left = centerX - halfSize
        let right = centerX + halfSize
        let top = centerY - halfSize
        let bottom = centerY + halfSize
        
        return point.x >= left && point.x <= right && point.y >= top && point.y <= bottom
    }
    
    private func isPointOnCorrectPath(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        if selectedShape == .square {
            return isPointOnSquarePath(point, size: canvasSize, centerX: centerX, centerY: centerY)
        } else {
            return isPointOnCirclePath(point, size: canvasSize, centerX: centerX, centerY: centerY)
        }
    }
    
    private func isPointOnSquarePath(_ point: CGPoint, size: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        let halfSize = size / 2
        let left = centerX - halfSize
        let right = centerX + halfSize
        let top = centerY - halfSize
        let bottom = centerY + halfSize
        
        // Check if point is near any of the four edges
        let nearLeftEdge = abs(point.x - left) <= pathTolerance && point.y >= top - pathTolerance && point.y <= bottom + pathTolerance
        let nearRightEdge = abs(point.x - right) <= pathTolerance && point.y >= top - pathTolerance && point.y <= bottom + pathTolerance
        let nearTopEdge = abs(point.y - top) <= pathTolerance && point.x >= left - pathTolerance && point.x <= right + pathTolerance
        let nearBottomEdge = abs(point.y - bottom) <= pathTolerance && point.x >= left - pathTolerance && point.x <= right + pathTolerance
        
        return nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge
    }
    
    private func isPointOnCirclePath(_ point: CGPoint, size: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        let radius = size / 2
        let distanceFromCenter = distance(from: point, to: CGPoint(x: centerX, y: centerY))
        
        // Check if point is near the circle circumference
        return abs(distanceFromCenter - radius) <= pathTolerance
    }
    
    private func isNearSquareCorner(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        let halfSize = canvasSize / 2
        let corners = [
            CGPoint(x: centerX - halfSize, y: centerY - halfSize), // Top-left
            CGPoint(x: centerX + halfSize, y: centerY - halfSize), // Top-right
            CGPoint(x: centerX + halfSize, y: centerY + halfSize), // Bottom-right
            CGPoint(x: centerX - halfSize, y: centerY + halfSize)  // Bottom-left
        ]
        
        // Check if point is near any corner
        for corner in corners {
            if distance(from: point, to: corner) <= cornerDetectionRadius {
                return true
            }
        }
        return false
    }
    
    private func getRelativePosition(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> String {
        if selectedShape == .square {
            let halfSize = canvasSize / 2
            let left = centerX - halfSize
            let right = centerX + halfSize
            let top = centerY - halfSize
            let bottom = centerY + halfSize
            
            // Determine which edge we're closest to
            if abs(point.x - left) < 30 && point.y >= top && point.y <= bottom {
                return "Left edge"
            } else if abs(point.x - right) < 30 && point.y >= top && point.y <= bottom {
                return "Right edge"
            } else if abs(point.y - top) < 30 && point.x >= left && point.x <= right {
                return "Top edge"
            } else if abs(point.y - bottom) < 30 && point.x >= left && point.x <= right {
                return "Bottom edge"
            }
            return "On square outline"
        } else {
            // For circle, give general position
            let angle = atan2(point.y - centerY, point.x - centerX)
            let degrees = angle * 180 / .pi
            
            if degrees >= -45 && degrees < 45 {
                return "Right side of circle"
            } else if degrees >= 45 && degrees < 135 {
                return "Bottom of circle"
            } else if degrees >= -135 && degrees < -45 {
                return "Top of circle"
            } else {
                return "Left side of circle"
            }
        }
    }
    

    private func clearTracingState() {
        tracedPath = []
        currentTouch = nil
        isOnCorrectPath = false
        traceManager.stopFeedback()
        print("📱 Shape changed - path cleared immediately")
    }
    
    private func announceCornerWithCooldown(at point: CGPoint) {
        let now = Date()
        
        // Check cooldown to prevent too frequent announcements
        if now.timeIntervalSince(lastCornerAnnouncementTime) < cornerAnnouncementCooldown {
            return
        }
        
        UIAccessibility.post(notification: .announcement, argument: "Corner")
        
        lastCornerAnnouncementTime = now
        lastAnnouncedCorner = point
    }
    
    private func checkAndAnnounceOutOfCanvas(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        let halfSize = canvasSize / 2
        let left = centerX - halfSize
        let right = centerX + halfSize
        let top = centerY - halfSize
        let bottom = centerY + halfSize
        
        // Check if point is outside the canvas bounds
        let isOutOfCanvas = point.x < left || point.x > right || point.y < top || point.y > bottom
        
        if isOutOfCanvas && !isCurrentlyOutOfCanvas {
            // Just went out of canvas - announce once (no haptic)
            isCurrentlyOutOfCanvas = true
            
            if UIAccessibility.isVoiceOverRunning {
                // Provide detailed directional guidance for VoiceOver users
                var directions: [String] = []
                
                if point.x < left {
                    directions.append("right")
                } else if point.x > right {
                    directions.append("left")
                }
                
                if point.y < top {
                    directions.append("down")
                } else if point.y > bottom {
                    directions.append("up")
                }
                
                let directionText = directions.joined(separator: " and ")
                let message = "Outside tracing area, move \(directionText) to return"
                
                UIAccessibility.post(notification: .announcement, argument: message)
            } else {
                // For non-VoiceOver users, provide audio feedback
                traceManager.audioManager.playWarningTone()
                print("⚠️ Out of canvas area - warning tone played")
            }
            
        } else if !isOutOfCanvas && isCurrentlyOutOfCanvas {
            // Just returned to canvas - stop out-of-canvas state
            isCurrentlyOutOfCanvas = false
            print("✅ Returned to canvas area")
        }
        
        // No ongoing haptic feedback while out of canvas
    }
    
    private func isPointNearPath(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        if selectedShape == .square {
            return isPointNearSquarePath(point, size: canvasSize, centerX: centerX, centerY: centerY, radius: proximityRadius)
        } else {
            return isPointNearCirclePath(point, size: canvasSize, centerX: centerX, centerY: centerY, radius: proximityRadius)
        }
    }
    
    private func isPointNearSquarePath(_ point: CGPoint, size: CGFloat, centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> Bool {
        let halfSize = size / 2
        let left = centerX - halfSize
        let right = centerX + halfSize
        let top = centerY - halfSize
        let bottom = centerY + halfSize
        
        // Check if point is near any of the four edges
        let nearLeftEdge = abs(point.x - left) <= radius && point.y >= top - radius && point.y <= bottom + radius
        let nearRightEdge = abs(point.x - right) <= radius && point.y >= top - radius && point.y <= bottom + radius
        let nearTopEdge = abs(point.y - top) <= radius && point.x >= left - radius && point.x <= right + radius
        let nearBottomEdge = abs(point.y - bottom) <= radius && point.x >= left - radius && point.x <= right + radius
        
        return nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge
    }
    
    private func isPointNearCirclePath(_ point: CGPoint, size: CGFloat, centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> Bool {
        let circleRadius = size / 2
        let distanceFromCenter = distance(from: point, to: CGPoint(x: centerX, y: centerY))
        
        // Check if point is near the circle circumference (within proximity radius)
        return abs(distanceFromCenter - circleRadius) <= radius
    }
    
    private func provideSpatialGuidance(for point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        let guidance = getSpatialGuidance(point, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        
        // Only announce if it's different from the last announcement
        if guidance != lastAnnouncedLocation {
            lastAnnouncedLocation = guidance
            UIAccessibility.post(notification: .announcement, argument: guidance)
            print("🗣️ Spatial guidance: \(guidance)")
        }
    }
    
    private func getSpatialGuidance(_ point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> String {
        if selectedShape == .square {
            let halfSize = canvasSize / 2
            let left = centerX - halfSize
            let right = centerX + halfSize
            let top = centerY - halfSize
            let bottom = centerY + halfSize
            
            // Calculate distances to each edge
            let distToLeft = abs(point.x - left)
            let distToRight = abs(point.x - right)
            let distToTop = abs(point.y - top)
            let distToBottom = abs(point.y - bottom)
            
            // Find which edge is closest
            let minDist = min(distToLeft, distToRight, distToTop, distToBottom)
            
            // Give specific directional instruction to reach the closest edge
            if minDist == distToLeft && point.y >= top && point.y <= bottom {
                if point.x > left {
                    return "Move left to reach the left edge"
                } else {
                    return "You're at the left edge! Move along it"
                }
            } else if minDist == distToRight && point.y >= top && point.y <= bottom {
                if point.x < right {
                    return "Move right to reach the right edge"
                } else {
                    return "You're at the right edge! Move along it"
                }
            } else if minDist == distToTop && point.x >= left && point.x <= right {
                if point.y > top {
                    return "Move up to reach the top edge"
                } else {
                    return "You're at the top edge! Move along it"
                }
            } else if minDist == distToBottom && point.x >= left && point.x <= right {
                if point.y < bottom {
                    return "Move down to reach the bottom edge"
                } else {
                    return "You're at the bottom edge! Move along it"
                }
            } else {
                // Handle corner cases
                var directions: [String] = []
                if point.x < left {
                    directions.append("right")
                } else if point.x > right {
                    directions.append("left")
                }
                if point.y < top {
                    directions.append("down")
                } else if point.y > bottom {
                    directions.append("up")
                }
                
                if !directions.isEmpty {
                    return "Move \(directions.joined(separator: " and ")) to reach the square"
                }
            }
            
            return "You're near the square outline"
            
        } else {
            // For circle, give directional guidance to the circumference
            let radius = canvasSize / 2
            let distanceFromCenter = distance(from: point, to: CGPoint(x: centerX, y: centerY))
            
            if distanceFromCenter < radius * 0.5 {
                // Inside circle, guide outward
                let angle = atan2(point.y - centerY, point.x - centerX)
                let degrees = angle * 180 / .pi
                
                if degrees >= -45 && degrees < 45 {
                    return "Move right to reach the circle edge"
                } else if degrees >= 45 && degrees < 135 {
                    return "Move down to reach the circle edge"
                } else if degrees >= -135 && degrees < -45 {
                    return "Move up to reach the circle edge"
                } else {
                    return "Move left to reach the circle edge"
                }
            } else if distanceFromCenter > radius * 1.5 {
                // Outside circle, guide inward
                let angle = atan2(centerY - point.y, centerX - point.x)
                let degrees = angle * 180 / .pi
                
                if degrees >= -45 && degrees < 45 {
                    return "Move right toward the circle"
                } else if degrees >= 45 && degrees < 135 {
                    return "Move down toward the circle"
                } else if degrees >= -135 && degrees < -45 {
                    return "Move up toward the circle"
                } else {
                    return "Move left toward the circle"
                }
            } else {
                // Near the circle
                if distanceFromCenter < radius {
                    return "Move slightly outward to reach the circle edge"
                } else {
                    return "Move slightly inward to reach the circle edge"
                }
            }
        }
    }
    
    private func getStartPoint(canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        if selectedShape == .square {
            // Middle of left edge (so user can trace the full square)
            let halfSize = canvasSize / 2
            return CGPoint(x: centerX - halfSize, y: centerY)
        } else {
            // Right side of circle (so user can trace the full circle)
            let radius = canvasSize / 2
            return CGPoint(x: centerX + radius, y: centerY)
        }
    }
    
    private func getStartInstruction() -> String {
        if selectedShape == .square {
            return "Start at the middle of the left edge. You'll trace around the full square."
        } else {
            return "Start at the right side of the circle. You'll trace around the full circle."
        }
    }
    
    private func getDirectionToStartPoint(from currentLocation: CGPoint, to startPoint: CGPoint) -> String {
        let deltaX = startPoint.x - currentLocation.x
        let deltaY = startPoint.y - currentLocation.y
        
        // Get primary direction (bigger movement)
        if abs(deltaX) > abs(deltaY) {
            if deltaX > 0 {
                return "Move right to find the start point."
            } else {
                return "Move left to find the start point."
            }
        } else {
            if deltaY > 0 {
                return "Move down to find the start point."
            } else {
                return "Move up to find the start point."
            }
        }
    }
    
    private func updateProgress(currentPoint: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        // Only count progress when on the actual path
        guard isPointOnCorrectPath(currentPoint, canvasSize: canvasSize, centerX: centerX, centerY: centerY) else { return }
        
        // Don't allow further tracing if already completed
        guard !isTraceComplete else { return }
        
        let pathSegment = getPathSegment(point: currentPoint, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        
        let wasNewSegment = !tracedPathCoverage.contains(pathSegment)
        tracedPathCoverage.insert(pathSegment)
        
        let totalPathSegments = getPathSegmentCount()
        let newProgress = Double(tracedPathCoverage.count) / Double(totalPathSegments)
        traceProgress = newProgress
        
        if newProgress >= 0.98 && !isTraceComplete {
            // Additional validation: check if the traced path covers the full shape properly
            if validateShapeCompletion(canvasSize: canvasSize, centerX: centerX, centerY: centerY) {
                completeShape()
            }
        }
        
        // Only announce progress when we hit a new segment and reach certain thresholds
        if wasNewSegment && UIAccessibility.isVoiceOverRunning && !isTraceComplete {
            let progressPercent = Int(newProgress * 100)
            
            if progressPercent >= 25 && lastProgressAnnouncement < 25 {
                lastProgressAnnouncement = 25
                UIAccessibility.post(notification: .announcement, argument: "25% of the shape traced. Keep going!")
            } else if progressPercent >= 50 && lastProgressAnnouncement < 50 {
                lastProgressAnnouncement = 50
                UIAccessibility.post(notification: .announcement, argument: "Halfway there! 50% traced.")
            } else if progressPercent >= 75 && lastProgressAnnouncement < 75 {
                lastProgressAnnouncement = 75
                let missingSides = getMissingSidesHint()
                UIAccessibility.post(notification: .announcement, argument: "75% traced. Almost done! \(missingSides)")
            }
        }
        
        print("📊 Progress: \(Int(newProgress * 100))% - Path segments traced: \(tracedPathCoverage.count)/\(totalPathSegments)")
    }
    
    private func getPathSegment(point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Int {
        if selectedShape == .square {
            return getSquarePathSegment(point: point, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        } else {
            return getCirclePathSegment(point: point, canvasSize: canvasSize, centerX: centerX, centerY: centerY)
        }
    }
    
    private func getSquarePathSegment(point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Int {
        let halfSize = canvasSize / 2
        let left = centerX - halfSize
        let right = centerX + halfSize
        let top = centerY - halfSize
        let bottom = centerY + halfSize
        
        // Determine which side of the square we're closest to
        let distToLeft = abs(point.x - left)
        let distToRight = abs(point.x - right)
        let distToTop = abs(point.y - top)
        let distToBottom = abs(point.y - bottom)
        
        let minDist = min(distToLeft, distToRight, distToTop, distToBottom)
        
        if minDist == distToTop {
            // Top side - 10 segments (0-9)
            let progress = (point.x - left) / canvasSize
            let segment = Int(progress * 10).clamped(to: 0...9)
            return segment
        } else if minDist == distToRight {
            // Right side - segments 10-19
            let progress = (point.y - top) / canvasSize
            let segment = Int(progress * 10).clamped(to: 0...9)
            return segment + 10
        } else if minDist == distToBottom {
            // Bottom side - segments 20-29 (reverse for clockwise)
            let progress = (right - point.x) / canvasSize
            let segment = Int(progress * 10).clamped(to: 0...9)
            return segment + 20
        } else {
            // Left side - segments 30-39 (reverse for clockwise)
            let progress = (bottom - point.y) / canvasSize
            let segment = Int(progress * 10).clamped(to: 0...9)
            return segment + 30
        }
    }
    
    private func getCirclePathSegment(point: CGPoint, canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Int {
        // Divide circle into 60 segments (6 degrees each for fine granularity)
        let angle = atan2(point.y - centerY, point.x - centerX)
        let degrees = angle * 180 / .pi
        
        // Normalize to 0-360 degrees, starting from top (adjust by 90 degrees)
        let adjustedDegrees = degrees + 90
        let normalizedDegrees = adjustedDegrees < 0 ? adjustedDegrees + 360 : adjustedDegrees
        
        // Return segment 0-59 (6 degrees each)
        return Int(normalizedDegrees / 6) % 60
    }
    
    private func getPathSegmentCount() -> Int {
        if selectedShape == .square {
            return 40 // 10 segments per side for very granular tracking
        } else {
            return 60 // 60 segments around circle (6 degrees each)
        }
    }
    
    private func resetProgress() {
        traceManager.stopFeedback()
        currentTouch = nil
        isOnCorrectPath = false
        
        withAnimation(.easeOut(duration: 0.3)) {
            tracedPath.removeAll()
            tracedPathCoverage.removeAll()  // CRITICAL: Clear path coverage
            traceProgress = 0.0
            hasCompletedShape = false
            completionTime = nil
            lastProgressAnnouncement = 0
            hasStartedTracing = false
            hasAnnouncedTracingStarted = false
            hasAnnouncedStartInstruction = false
            isCurrentlyOffPath = false
            isOutOfCanvas = false
            isTraceComplete = false
            
            lastOutOfCanvasAnnouncementTime = Date(timeIntervalSince1970: 0)
            lastOffPathFeedbackTime = Date(timeIntervalSince1970: 0)
            lastSpatialGuidanceTime = Date(timeIntervalSince1970: 0)
            lastAnnouncedLocation = ""
        }
        print("🔄 COMPLETE RESET: All progress, audio, and state cleared - Ready for fresh start")
    }
    
    private func completeShape() {
        isTraceComplete = true
        hasCompletedShape = true
        completionTime = Date()
        lastProgressAnnouncement = 100
        
        currentTouch = nil
        isOnCorrectPath = false
        traceManager.stopFeedback()
        
        UIAccessibility.post(notification: .announcement, argument: "Perfect! Shape completed! You made it!")
        
        print("🎉 Shape completion validated with proper shape!")
    }
    
    private func validateShapeCompletion(canvasSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Bool {
        // Meaningful validation - ensure user has traced a complete shape to understand its form
        guard tracedPathCoverage.count >= Int(Double(getPathSegmentCount()) * 0.98) else { return false }
        
        if selectedShape == .square {
            let sidesCount = [
                tracedPathCoverage.filter { $0 < 10 }.count,
                tracedPathCoverage.filter { $0 >= 10 && $0 < 20 }.count,
                tracedPathCoverage.filter { $0 >= 20 && $0 < 30 }.count,
                tracedPathCoverage.filter { $0 >= 30 && $0 < 40 }.count
            ]
            // Each side should have substantial coverage for learning the shape
            return sidesCount.allSatisfy { $0 >= 7 }
        } else {
            let quarterCounts = [
                tracedPathCoverage.filter { $0 < 15 }.count,
                tracedPathCoverage.filter { $0 >= 15 && $0 < 30 }.count,
                tracedPathCoverage.filter { $0 >= 30 && $0 < 45 }.count,
                tracedPathCoverage.filter { $0 >= 45 && $0 < 60 }.count
            ]
            // Each quarter should have good coverage for understanding the circular form
            return quarterCounts.allSatisfy { $0 >= 11 }
        }
    }
    
    private func getMissingSidesHint() -> String {
        if selectedShape == .square {
            let sidesCount = [
                tracedPathCoverage.filter { $0 < 10 }.count,
                tracedPathCoverage.filter { $0 >= 10 && $0 < 20 }.count,
                tracedPathCoverage.filter { $0 >= 20 && $0 < 30 }.count,
                tracedPathCoverage.filter { $0 >= 30 && $0 < 40 }.count
            ]
            
            var missingSides: [String] = []
            let sideNames = ["top", "right", "bottom", "left"]
            
            for (index, count) in sidesCount.enumerated() {
                if count < 7 {
                    missingSides.append(sideNames[index])
                }
            }
            
            if missingSides.isEmpty {
                return "Keep tracing to complete the shape!"
            } else if missingSides.count == 1 {
                return "Focus on the \(missingSides[0]) side."
            } else {
                return "Focus on the \(missingSides.joined(separator: " and ")) sides."
            }
        } else {
            let quarterCounts = [
                tracedPathCoverage.filter { $0 < 15 }.count,
                tracedPathCoverage.filter { $0 >= 15 && $0 < 30 }.count,
                tracedPathCoverage.filter { $0 >= 30 && $0 < 45 }.count,
                tracedPathCoverage.filter { $0 >= 45 && $0 < 60 }.count
            ]
            
            var missingQuarters: [String] = []
            let quarterNames = ["top-right", "bottom-right", "bottom-left", "top-left"]
            
            for (index, count) in quarterCounts.enumerated() {
                if count < 11 {
                    missingQuarters.append(quarterNames[index])
                }
            }
            
            if missingQuarters.isEmpty {
                return "Keep tracing to complete the shape!"
            } else if missingQuarters.count == 1 {
                return "Focus on the \(missingQuarters[0]) part of the circle."
            } else {
                return "Focus on the \(missingQuarters.joined(separator: " and ")) parts of the circle."
            }
        }
    }
    
    private var completionOverlay: some View {
        VStack {
            Spacer() // Push content to bottom
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isTraceComplete)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Perfect!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("You completed the \(selectedShape.rawValue)!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Perfect! You completed the \(selectedShape.rawValue)!")
                
                Spacer()
                
                Button("Trace Again") {
                    resetProgress()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

struct ShapeSelectionView: View {
    @Binding var selectedShape: ShapeType
    
    private let primaryColor = Color.accentColor
    private let secondaryColor = Color.secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(primaryColor)
                    .accessibilityHidden(true)
                Text("Select a Shape")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Shape Selection")
            .accessibilityHint("Choose which shape you want to trace below")

            HStack(spacing: 20) {
                ForEach(ShapeType.allCases, id: \.self) { shape in
                    ShapeButton(shape: shape, isSelected: shape == selectedShape, action: { selectedShape = shape })
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Available shapes")
        }
    }
}

struct ShapeButton: View {
    let shape: ShapeType
    let isSelected: Bool
    let action: () -> Void
    
    private let primaryColor = Color.accentColor
    private let secondaryColor = Color.secondary
    
    var body: some View {
        Button(action: {
            action()
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, 
                                       argument: "Please move below to the tracing area to start")
                }
            }
        }) {
            VStack(spacing: 12) {
                Group {
                    switch shape {
                    case .square:
                        Rectangle()
                            .stroke(lineWidth: 3)
                            .frame(width: 44, height: 44)
                    case .circle:
                        Circle()
                            .stroke(lineWidth: 3)
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundColor(isSelected ? primaryColor : secondaryColor)

                            Text(shape.rawValue.capitalized)
                .font(.headline) // Dynamic Type support
                .foregroundColor(isSelected ? primaryColor : secondaryColor)
            }
            .frame(minWidth: 90, minHeight: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? primaryColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? primaryColor : secondaryColor.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: isSelected ? primaryColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shape.rawValue)
        .accessibilityValue(isSelected ? "Currently selected" : "Not selected")
        .accessibilityHint(isSelected ? 
            "Move to tracing area below to start" :
            "Double tap to change to this shape")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    ContentView()
}



