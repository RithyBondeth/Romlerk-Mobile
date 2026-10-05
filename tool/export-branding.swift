// Export the approved artwork into platform assets without changing its design.
// Usage: swift scripts/export-branding.swift /path/to/export-manifest.json
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct Job: Decodable { let path: String; let size: Int; let opaque: Bool; let fraction: Double }
struct Manifest: Decodable { let source: String; let jobs: [Job] }
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
let base = manifestURL.deletingLastPathComponent()
func resolve(_ path: String) -> URL { base.appendingPathComponent(path).standardizedFileURL }
let bitmap = NSBitmapImageRep(data: try Data(contentsOf: resolve(manifest.source)))!
let original = bitmap.cgImage!
// Alpha bounds remove the generator's empty margins, preserving every drawn pixel.
var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = 0, maxY = 0
for y in 0..<bitmap.pixelsHigh {
  for x in 0..<bitmap.pixelsWide {
    if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.01 {
      minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
    }
  }
}
let crop = CGRect(x: max(0, minX-2), y: max(0, minY-2), width: min(bitmap.pixelsWide-minX+2, maxX-minX+5), height: min(bitmap.pixelsHigh-minY+2, maxY-minY+5))
let artwork = original.cropping(to: crop)!
for job in manifest.jobs {
  let size = job.size
  let alpha = job.opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
  let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alpha.rawValue)!
  if job.opaque {
    context.setFillColor(CGColor(red: 244/255, green: 247/255, blue: 252/255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
  }
  let scale = Double(size)*job.fraction/Double(max(artwork.width, artwork.height))
  let w = Double(artwork.width)*scale, h = Double(artwork.height)*scale
  context.interpolationQuality = .high
  context.draw(artwork, in: CGRect(x: (Double(size)-w)/2, y: (Double(size)-h)/2, width: w, height: h))
  let output = resolve(job.path)
  try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
  let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, context.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(destination), "Failed to export \(job.path)")
}
print("Exported \(manifest.jobs.count) branding assets")
