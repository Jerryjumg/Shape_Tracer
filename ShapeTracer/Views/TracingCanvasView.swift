import SwiftUI

struct TracingCanvasView: View {
    init(shape: TraceableShape, traceManager: TraceManager) {
        print("📱 Creating TracingCanvasView - no params stored")
        // Don't store anything
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .overlay(
                Text("Test TracingCanvasView")
                    .foregroundColor(.gray)
            )
            .onAppear {
                print("📱 TracingCanvasView appeared - no params")
            }
    }
}
