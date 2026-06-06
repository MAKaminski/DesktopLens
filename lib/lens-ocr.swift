// DesktopLens — on-device OCR via Apple Vision. Prints recognized text to stdout.
// Usage: lens-ocr <image-path>   (no network; nothing leaves the machine)
import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: lens-ocr <image>\n".data(using: .utf8)!)
    exit(1)
}
let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path),
      let tiff = img.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let cg = bitmap.cgImage else {
    exit(0)   // unreadable image -> empty output, not an error
}
let req = VNRecognizeTextRequest()
req.recognitionLevel = .accurate
req.usesLanguageCorrection = true
let handler = VNImageRequestHandler(cgImage: cg, options: [:])
try? handler.perform([req])
if let results = req.results {
    for obs in results {
        if let top = obs.topCandidates(1).first { print(top.string) }
    }
}
