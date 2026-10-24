// vision_ocr.swift — Apple Vision OCR for the screen-tutor engine.
//
// Native, offline, arm64. Reads an image and prints a JSON array of recognized
// text with pixel bounding boxes (top-left origin, matching the screenshot's
// pixel space) so screen_tutor.py can map them to screen points via the sidecar.
//
// Usage:  swift vision_ocr.swift <image-path> [min-confidence]
// Output: [{"text":"Save","x":..,"y":..,"w":..,"h":..,"conf":0.97}, ...]

import CoreGraphics
import Foundation
import ImageIO
import Vision

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: vision_ocr <image> [minConf]\n".utf8))
    exit(2)
}
let path = args[1]
let minConf = args.count >= 3 ? (Float(args[2]) ?? 0.0) : 0.0

guard
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("error: cannot load image \(path)\n".utf8))
    exit(1)
}

let width = CGFloat(image.width)
let height = CGFloat(image.height)

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: image, options: [:])
do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}

var out: [[String: Any]] = []
for observation in (request.results ?? []) {
    guard let candidate = observation.topCandidates(1).first else { continue }
    if candidate.confidence < minConf { continue }
    // Vision boundingBox is normalized [0,1] with a bottom-left origin; convert
    // to top-left pixel coordinates so it matches the captured PNG.
    let box = observation.boundingBox
    out.append([
        "text": candidate.string,
        "x": Double(box.minX * width),
        "y": Double((1 - box.maxY) * height),
        "w": Double(box.width * width),
        "h": Double(box.height * height),
        "conf": Double(candidate.confidence),
    ])
}

let data = try JSONSerialization.data(withJSONObject: out, options: [])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
