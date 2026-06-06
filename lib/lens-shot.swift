// DesktopLens — native screenshot via ScreenCaptureKit.
// Usage: lens-shot <out.jpg>
// Unlike a bash->screencapture chain, this binary is the responsible process for
// the screen API, so it appears by name in System Settings > Screen Recording and
// can be granted to a background LaunchAgent.
import ScreenCaptureKit
import AppKit
import Foundation

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out.jpg"
let sem = DispatchSemaphore(value: 0)
var code: Int32 = 0

Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Prefer the main display; fall back to the first available.
        let mainID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainID })
                            ?? content.displays.first else { code = 2; sem.signal(); return }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.width = display.width
        cfg.height = display.height
        let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
            try data.write(to: URL(fileURLWithPath: out))
        } else { code = 4 }
    } catch {
        FileHandle.standardError.write("lens-shot error: \(error)\n".data(using: .utf8)!)
        code = 3
    }
    sem.signal()
}
sem.wait()
exit(code)
