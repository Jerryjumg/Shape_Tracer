//
//  ShapeTracerTests.swift
//  ShapeTracerTests
//
//  Created by Jerry Jung on 6/6/25.
//

import XCTest
import CoreGraphics
@testable import ShapeTracer

final class ShapeTracerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Shape Tracing Validation Logic Tests
    
    func testSquarePathGeneration() throws {
        // Test that square generates correct path points
        let shape = TraceableShape(type: .square)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pathPoints = shape.squarePathPoints(in: testRect)
        
        // Verify we get expected number of points (4 sides * 25 points per side + overlaps)
        XCTAssertTrue(pathPoints.count > 100, "Square should generate sufficient path points")
        
        // Verify first point is top-left corner (with 20pt inset)
        let firstPoint = pathPoints.first!
        XCTAssertEqual(firstPoint.x, 20, accuracy: 1.0, "First point should be at left edge with inset")
        XCTAssertEqual(firstPoint.y, 20, accuracy: 1.0, "First point should be at top edge with inset")
        
        // Verify path follows square perimeter
        let insetRect = testRect.insetBy(dx: 20, dy: 20)
        for point in pathPoints {
            let isOnPerimeter = (point.x == insetRect.minX || point.x == insetRect.maxX) ||
                               (point.y == insetRect.minY || point.y == insetRect.maxY)
            XCTAssertTrue(isOnPerimeter, "All points should be on square perimeter")
        }
    }
    
    func testCirclePathGeneration() throws {
        // Test that circle generates correct path points
        let shape = TraceableShape(type: .circle)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pathPoints = shape.circlePathPoints(in: testRect)
        
        // Verify we get expected number of points
        XCTAssertEqual(pathPoints.count, 101, "Circle should generate 101 path points (0 to 100 inclusive)")
        
        // Calculate expected circle parameters
        let insetRect = testRect.insetBy(dx: 20, dy: 20)
        let center = CGPoint(x: insetRect.midX, y: insetRect.midY)
        let radius = min(insetRect.width, insetRect.height) / 2
        
        // Verify all points are on circle circumference
        for point in pathPoints {
            let distance = hypot(point.x - center.x, point.y - center.y)
            XCTAssertEqual(distance, radius, accuracy: 1.0, "All points should be on circle circumference")
        }
    }
    
    func testPointNearPathValidation() throws {
        // Test path proximity detection
        let shape = TraceableShape(type: .square)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pathPoints = shape.squarePathPoints(in: testRect)
        
        // Test point on path
        let pointOnPath = pathPoints[10] // Take a point from the path
        XCTAssertTrue(shape.isPoint(pointOnPath, nearPath: pathPoints, tolerance: 10),
                     "Point on path should be detected as near path")
        
        // Test point near path (within tolerance)
        let pointNearPath = CGPoint(x: pathPoints[10].x + 5, y: pathPoints[10].y + 5)
        XCTAssertTrue(shape.isPoint(pointNearPath, nearPath: pathPoints, tolerance: 10),
                     "Point within tolerance should be detected as near path")
        
        // Test point far from path (outside tolerance)
        let pointFarFromPath = CGPoint(x: 150, y: 150) // Center of square
        XCTAssertFalse(shape.isPoint(pointFarFromPath, nearPath: pathPoints, tolerance: 10),
                      "Point far from path should not be detected as near path")
    }
    
    func testVertexDetection() throws {
        // Test vertex detection for square
        let shape = TraceableShape(type: .square)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let insetRect = testRect.insetBy(dx: 20, dy: 20)
        
        // Test points near vertices
        let topLeftVertex = CGPoint(x: insetRect.minX, y: insetRect.minY)
        let nearTopLeft = CGPoint(x: topLeftVertex.x + 10, y: topLeftVertex.y + 10)
        
        let detectedVertex = shape.nearestVertex(to: nearTopLeft, in: testRect)
        XCTAssertNotNil(detectedVertex, "Should detect vertex when point is near")
        XCTAssertEqual(detectedVertex!.x, topLeftVertex.x, accuracy: 1.0)
        XCTAssertEqual(detectedVertex!.y, topLeftVertex.y, accuracy: 1.0)
        
        // Test point far from any vertex
        let centerPoint = CGPoint(x: 150, y: 150)
        let noVertex = shape.nearestVertex(to: centerPoint, in: testRect)
        XCTAssertNil(noVertex, "Should not detect vertex when point is far from all vertices")
        
        // Test that circle returns nil for vertex detection
        let circleShape = TraceableShape(type: .circle)
        let circleVertex = circleShape.nearestVertex(to: nearTopLeft, in: testRect)
        XCTAssertNil(circleVertex, "Circle should not have vertices")
    }
    
    func testPathValidationAccuracy() throws {
        // Test edge cases for path validation
        let shape = TraceableShape(type: .circle)
        let testRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let pathPoints = shape.circlePathPoints(in: testRect)
        
        // Test with different tolerance values
        let testPoint = pathPoints[0] // Point on path
        
        XCTAssertTrue(shape.isPoint(testPoint, nearPath: pathPoints, tolerance: 0),
                     "Point exactly on path should be valid with zero tolerance")
        
        XCTAssertTrue(shape.isPoint(testPoint, nearPath: pathPoints, tolerance: 5),
                     "Point on path should be valid with any positive tolerance")
        
        // Test boundary conditions
        let slightlyOffPoint = CGPoint(x: testPoint.x + 3, y: testPoint.y + 3)
        XCTAssertFalse(shape.isPoint(slightlyOffPoint, nearPath: pathPoints, tolerance: 2),
                      "Point just outside tolerance should be invalid")
        XCTAssertTrue(shape.isPoint(slightlyOffPoint, nearPath: pathPoints, tolerance: 5),
                     "Point within tolerance should be valid")
    }
    
    // MARK: - Feedback Triggering Accuracy Tests
    
    func testTraceManagerFeedbackInitialization() throws {
        // Test that TraceManager initializes correctly
        let traceManager = TraceManager()
        
        XCTAssertNotNil(traceManager, "TraceManager should initialize successfully")
        XCTAssertFalse(traceManager.isTracing, "Should not be tracing initially")
        XCTAssertEqual(traceManager.traceProgress, 0.0, "Initial progress should be zero")
    }
    
    func testShapeAssignment() throws {
        // Test shape assignment and validation
        let traceManager = TraceManager()
        let square = TraceableShape(type: .square)
        
        traceManager.setShape(square)
        XCTAssertEqual(traceManager.currentShape?.type, .square, "Shape should be assigned correctly")
        
        let circle = TraceableShape(type: .circle)
        traceManager.setShape(circle)
        XCTAssertEqual(traceManager.currentShape?.type, .circle, "Shape should be updated correctly")
    }
    
    func testFeedbackTriggeringConditions() throws {
        // Test the conditions that should trigger feedback
        let traceManager = TraceManager()
        let shape = TraceableShape(type: .square)
        traceManager.setShape(shape)
        
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        
        // Test that correct path triggers feedback
        // This tests the underlying logic without actually playing audio/haptics
        let pathPoints = shape.squarePathPoints(in: testRect)
        let pointOnPath = pathPoints[10]
        
        // Test path proximity detection (the core logic for feedback triggering)
        XCTAssertTrue(shape.isPoint(pointOnPath, nearPath: pathPoints, tolerance: 20),
                     "Point on correct path should trigger feedback")
        
        // Test vertex proximity detection
        let vertexPoint = shape.nearestVertex(to: pointOnPath, in: testRect)
        // This tests if we can detect vertices for enhanced feedback
        if shape.type == .square {
            // For points near vertices, we should either detect the vertex or be on the path
            XCTAssertTrue(vertexPoint != nil || shape.isPoint(pointOnPath, nearPath: pathPoints, tolerance: 20),
                         "Point should either be near vertex or on path for feedback")
        }
    }
    
    func testFeedbackAccuracyWithDifferentShapes() throws {
        // Test feedback triggering accuracy for different shapes
        let traceManager = TraceManager()
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        
        // Test square feedback accuracy
        let square = TraceableShape(type: .square)
        traceManager.setShape(square)
        let squarePoints = square.squarePathPoints(in: testRect)
        
        // Test multiple points on square path
        for i in stride(from: 0, to: squarePoints.count, by: 10) {
            let point = squarePoints[i]
            XCTAssertTrue(square.isPoint(point, nearPath: squarePoints, tolerance: 15),
                         "Square path point \(i) should trigger feedback")
        }
        
        // Test circle feedback accuracy
        let circle = TraceableShape(type: .circle)
        traceManager.setShape(circle)
        let circlePoints = circle.circlePathPoints(in: testRect)
        
        // Test multiple points on circle path
        for i in stride(from: 0, to: circlePoints.count, by: 10) {
            let point = circlePoints[i]
            XCTAssertTrue(circle.isPoint(point, nearPath: circlePoints, tolerance: 15),
                         "Circle path point \(i) should trigger feedback")
        }
    }
    
    func testFeedbackToleranceAccuracy() throws {
        // Test that feedback tolerance is accurate and consistent
        let shape = TraceableShape(type: .circle)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pathPoints = shape.circlePathPoints(in: testRect)
        
        // Use center point for testing radial distances
        let insetRect = testRect.insetBy(dx: 20, dy: 20)
        let center = CGPoint(x: insetRect.midX, y: insetRect.midY)
        let radius = min(insetRect.width, insetRect.height) / 2
        
        let tolerance: CGFloat = 20
        
        // Test points at various distances from the path
        // Offset perpendicular to the circle to ensure proper distance measurement
        let testDistances: [CGFloat] = [0, 5, 10, 15, 19, 20, 21, 25, 30]
        
        for distance in testDistances {
            // Move the point radially outward from the circle
            let offsetPoint = CGPoint(x: center.x + radius + distance, y: center.y)
            let shouldTrigger = distance <= tolerance
            let actuallyTriggers = shape.isPoint(offsetPoint, nearPath: pathPoints, tolerance: tolerance)
            
            XCTAssertEqual(actuallyTriggers, shouldTrigger,
                          "Point at distance \(distance) should \(shouldTrigger ? "trigger" : "not trigger") feedback")
        }
    }
    
    func testVertexFeedbackAccuracy() throws {
        // Test that vertex feedback is triggered accurately
        let shape = TraceableShape(type: .square)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let insetRect = testRect.insetBy(dx: 20, dy: 20)
        
        // Define all square vertices
        let vertices = [
            CGPoint(x: insetRect.minX, y: insetRect.minY), // top-left
            CGPoint(x: insetRect.maxX, y: insetRect.minY), // top-right
            CGPoint(x: insetRect.maxX, y: insetRect.maxY), // bottom-right
            CGPoint(x: insetRect.minX, y: insetRect.maxY)  // bottom-left
        ]
        
        // Test points near each vertex
        for (index, vertex) in vertices.enumerated() {
            // Point very close to vertex (should trigger vertex feedback)
            let nearVertex = CGPoint(x: vertex.x + 5, y: vertex.y + 5)
            let detectedVertex = shape.nearestVertex(to: nearVertex, in: testRect)
            XCTAssertNotNil(detectedVertex, "Point near vertex \(index) should detect vertex")
            
            // Point far from vertex (should not trigger vertex feedback)
            let farFromVertex = CGPoint(x: vertex.x + 50, y: vertex.y + 50)
            let noDetectedVertex = shape.nearestVertex(to: farFromVertex, in: testRect)
            XCTAssertNil(noDetectedVertex, "Point far from vertex \(index) should not detect vertex")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        let shape = TraceableShape(type: .circle)
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        
        self.measure {
            // Test performance of path generation and validation
            let pathPoints = shape.circlePathPoints(in: testRect)
            let testPoint = CGPoint(x: 150, y: 50)
            _ = shape.isPoint(testPoint, nearPath: pathPoints, tolerance: 20)
        }
    }
}
