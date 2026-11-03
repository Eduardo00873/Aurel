// Composes a README screenshot: a popup or window capture, masked to its rounded panel,
// centred on a soft neutral background with a soft shadow.
//
// Usage: swift scripts/readme-screenshot.swift <capture.png> <output.png> <left> <top> <right> <bottom> [radius]
// The four numbers are the panel's edges in pixels inside the capture (crop away anything behind it).
import AppKit
let args = CommandLine.arguments
let src = NSImage(contentsOfFile: args[1])!
let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil)!
// Panel bounds in source pixels (left, top, right, bottom) and corner radius.
let n = args[3...].compactMap { Double($0) }.map { CGFloat($0) }
let (l, t, r, b) = (n[0], n[1], n[2], n[3])
let radius: CGFloat = n.count > 4 ? n[4] : 30
let W: CGFloat = 2400, H: CGFloat = 1500
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.displayP3)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Background: soft neutral gradient + gentle glow behind the panel.
let bg = CGGradient(colorsSpace: nil, colors: [
    CGColor(red: 246/255, green: 247/255, blue: 250/255, alpha: 1),
    CGColor(red: 226/255, green: 229/255, blue: 236/255, alpha: 1)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
let glow = CGGradient(colorsSpace: nil, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.22), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: W/2, y: H/2 + 60), startRadius: 0,
                       endCenter: CGPoint(x: W/2, y: H/2 + 60), endRadius: 900, options: [])
// Panel, scaled and centred.
// Up to 1.85× the capture, but never taller than 82% of the canvas.
let scale: CGFloat = min(1.85, 0.82 * H / (b - t))
let pw = (r - l) * scale, ph = (b - t) * scale
let dest = CGRect(x: (W - pw)/2, y: (H - ph)/2, width: pw, height: ph)
let path = CGPath(roundedRect: dest, cornerWidth: radius*scale, cornerHeight: radius*scale, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 120, color: CGColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 0.28))
ctx.addPath(path); ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(path); ctx.clip()
let crop = cg.cropping(to: CGRect(x: l, y: t, width: r - l, height: b - t))!
ctx.interpolationQuality = .high
ctx.draw(crop, in: dest)
ctx.restoreGState()
// Hairline border like a macOS panel.
ctx.addPath(path); ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.10)); ctx.setLineWidth(2); ctx.strokePath()
let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
