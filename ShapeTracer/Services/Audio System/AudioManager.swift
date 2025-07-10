import AVFoundation

class AudioManager {
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var mixer: AVAudioMixerNode?
    private var isEngineRunning = false
    
    private let baseVolume: Float = 0.3
    private let maxVolume: Float = 0.4
    
    init() {
        print("🔊 Initializing AudioManager")
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        tonePlayer = AVAudioPlayerNode()
        mixer = audioEngine?.mainMixerNode
        
        guard let _ = audioEngine,
              let player = tonePlayer,
              let mixer = mixer else {
            print("❌ Failed to create audio engine components")
            return
        }
        
        audioEngine?.attach(player)
        
        let outputFormat = mixer.outputFormat(forBus: 0)
        audioEngine?.connect(player, to: mixer, format: outputFormat)
        
        do {
            try audioEngine?.start()
            isEngineRunning = true
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
            isEngineRunning = false
        }
    }
    
    func playTone(frequency: Double, volume: Float = 1.0) {
        guard let _ = audioEngine,
              let player = tonePlayer,
              let mixer = mixer,
              isEngineRunning else {
            print("❌ Audio engine not ready")
            // Try to restart the engine if it failed
            if !isEngineRunning {
                setupAudioEngine()
            }
            return
        }
        
        let outputFormat = mixer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let duration: Double = 0.1
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let finalVolume = min(baseVolume * volume, maxVolume)
        
        for channel in 0..<Int(outputFormat.channelCount) {
            let channelData = buffer.floatChannelData?[channel]
            let omega = 2.0 * .pi * frequency
            
            for frame in 0..<Int(frameCount) {
                let value = sin(omega * Double(frame) / sampleRate)
                // Apply soft limiting to prevent harsh sounds
                let limitedValue = tanh(value * 0.8)
                channelData?[frame] = Float(limitedValue) * finalVolume
            }
        }
        
        player.scheduleBuffer(buffer, at: nil, options: .loops) {
            print("✅ Tone playback completed")
        }
        player.play()
        print("🔊 Playing tone at \(frequency)Hz with volume \(finalVolume)")
    }
    
    func stopTone() {
        tonePlayer?.stop()
        print("🔇 Stopped tone playback")
    }
    
    func forceStopAllAudio() {
        print("🔇 FORCE STOP INITIATED")
        
        tonePlayer?.stop()
        tonePlayer?.stop()
        tonePlayer?.reset()
        
        if let player = tonePlayer {
            player.reset()
        }
        
        if let engine = audioEngine, let player = tonePlayer {
            engine.detach(player)
        }
        
        audioEngine?.stop()
        audioEngine?.reset()
        isEngineRunning = false
        
        print("🔇 NUCLEAR STOP: Audio engine completely destroyed")
        
        // Restart the engine clean for future use
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupAudioEngine()
        }
    }
    
    func playWarningTone() {
        let warningFrequency = 220.0 // A3 note - lower and more noticeable
        playTone(frequency: warningFrequency, volume: 0.8)
        print("⚠️ Playing warning tone at \(warningFrequency)Hz")
    }
    
    deinit {
        print("🔊 Cleaning up AudioManager")
        audioEngine?.stop()
    }
}
