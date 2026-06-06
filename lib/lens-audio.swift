// DesktopLens — capture SYSTEM (output) audio via ScreenCaptureKit -> WAV.
// No virtual device, no output rerouting, no volume change. Needs Screen Recording perm.
// Usage: lens-audio <out.wav> [seconds]
import ScreenCaptureKit
import AVFoundation
import CoreMedia

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "sys.wav"
let seconds = Double(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "10") ?? 10

final class VideoSink: NSObject, SCStreamOutput {
    func stream(_ s: SCStream, didOutputSampleBuffer b: CMSampleBuffer, of t: SCStreamOutputType) {}
}

final class AudioSink: NSObject, SCStreamOutput {
    let url: URL; var file: AVAudioFile?; var wrote = false
    init(_ u: URL) { url = u }
    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sb) else { return }
        guard let fd = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd) else { return }
        var sd = asbd.pointee
        guard let fmt = AVAudioFormat(streamDescription: &sd) else { return }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
        guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return }
        pcm.frameLength = frames
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(frames),
              into: pcm.mutableAudioBufferList) == noErr else { return }
        do {
            if file == nil { file = try AVAudioFile(forWriting: url, settings: fmt.settings) }
            try file?.write(from: pcm); wrote = true
        } catch { FileHandle.standardError.write("write: \(error)\n".data(using:.utf8)!) }
    }
}

let sem = DispatchSemaphore(value: 0)
var rc: Int32 = 0
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else { rc = 2; sem.signal(); return }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.sampleRate = 48000
        cfg.channelCount = 2
        cfg.excludesCurrentProcessAudio = true
        cfg.width = 192; cfg.height = 108
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 2) // ~0.5 fps, frames discarded
        let audio = AudioSink(URL(fileURLWithPath: outPath))
        let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try stream.addStreamOutput(audio, type: .audio, sampleHandlerQueue: DispatchQueue(label: "dl.audio"))
        try stream.addStreamOutput(VideoSink(), type: .screen, sampleHandlerQueue: DispatchQueue(label: "dl.video"))
        try await stream.startCapture()
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        try await stream.stopCapture()
        rc = audio.wrote ? 0 : 5
    } catch {
        FileHandle.standardError.write("lens-audio error: \(error)\n".data(using: .utf8)!)
        rc = 3
    }
    sem.signal()
}
sem.wait()
exit(rc)
