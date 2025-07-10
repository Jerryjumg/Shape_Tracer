import CoreHaptics
import UIKit

class HapticManager {
    private var engine: CHHapticEngine?
    private var isEngineRunning = false
    private var player: CHHapticPatternPlayer?
    private var setupRetryCount = 0
    private let maxRetryCount = 3
    
    init() {
        print("📳 Initializing HapticManager")
        setupHaptics()
    }
    
     func setupHaptics() {
        print("📳 Setting up haptics...")
        
        // Prevent infinite retry loops
        guard setupRetryCount < maxRetryCount else {
            print("❌ Max retry count reached, disabling haptics")
            return
        }
        
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("❌ Device does not support haptics")
            return
        }
        
        do {
            print("📳 Creating haptic engine...")
            engine = try CHHapticEngine()
            
            engine?.resetHandler = { [weak self] in
                print("🔄 Haptic engine reset")
                DispatchQueue.main.async {
                    self?.isEngineRunning = false
                    self?.setupRetryCount = 0 // Reset retry count on reset
                    self?.setupHaptics()
                }
            }
            
            engine?.stoppedHandler = { [weak self] reason in
                print("⚠️ Haptic engine stopped: \(reason)")
                self?.isEngineRunning = false
                
                // Only try to restart for certain reasons, not for all errors
                if reason == .audioSessionInterrupt || reason == .applicationSuspended {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.setupRetryCount += 1
                        self?.setupHaptics()
                    }
                } else {
                    print("📳 Haptic engine stopped for non-recoverable reason, not restarting")
                }
            }
            
            print("📳 Starting haptic engine...")
            try engine?.start()
            isEngineRunning = true
            setupRetryCount = 0 // Reset on successful start
            print("✅ Haptic engine started successfully")
        } catch {
            print("❌ Failed to create haptic engine: \(error.localizedDescription)")
            isEngineRunning = false
            setupRetryCount += 1
        }
    }
    
    private func ensureEngineRunning() -> Bool {
        guard let engine = engine else {
            print("❌ Haptic engine not available")
            setupHaptics()
            return false
        }
        
        if !isEngineRunning {
            do {
                try engine.start()
                isEngineRunning = true
                print("✅ Haptic engine restarted successfully")
            } catch {
                print("❌ Failed to restart haptic engine: \(error.localizedDescription)")
                return false
            }
        }
        
        return true
    }
    
    func playHaptic(intensity: Float, sharpness: Float) {
        guard ensureEngineRunning() else { return }
        
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(eventType: .hapticTransient, 
                                parameters: [intensityParameter, sharpnessParameter], 
                                relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            print("✅ Haptic feedback played successfully")
        } catch {
            print("❌ Failed to play haptic feedback: \(error.localizedDescription)")
            // Try to restart the engine if it failed
            setupHaptics()
        }
    } 
    
    func stopHaptic() {
        do {
            try player?.stop(atTime: 0)
            engine?.stop()
            isEngineRunning = false
            print("📳 Stopped haptic feedback")
        } catch {
            print("❌ Failed to stop haptic feedback: \(error.localizedDescription)")
            // Try to force stop the engine
            engine?.stop()
            isEngineRunning = false
        }
    }
    
    deinit {
        print("📳 Cleaning up HapticManager")
        stopHaptic()
    }
} 
