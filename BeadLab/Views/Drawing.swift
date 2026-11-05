import SwiftUI

let beadColors: [Color] = [.cobalt, .ochre, .muted]

// Draw one Picture into a SwiftUI Canvas. Simulation y points up, screen y points down.
func draw(_ pic: Picture, in ctx: inout GraphicsContext, size: CGSize) {
    let s = size.width / CGFloat(pic.box.x)
    func point(_ p: Vec) -> CGPoint { CGPoint(x: CGFloat(p.x) * s, y: size.height - CGFloat(p.y) * s) }

    if !pic.field.isEmpty, let image = fieldImage(pic) {
        ctx.draw(Image(decorative: image, scale: 1).interpolation(.none), in: CGRect(origin: .zero, size: size))
    }

    if pic.wall {
        ctx.fill(Path(CGRect(x: 0, y: size.height - 3, width: size.width, height: 3)), with: .color(.muted))
    }

    // bonds, skipping the ones that cross the periodic boundary
    if !pic.bonds.isEmpty {
        var path = Path()
        let half = pic.box / 2
        var k = 0
        while k < pic.bonds.count {
            let a = pic.beads[Int(pic.bonds[k])], b = pic.beads[Int(pic.bonds[k + 1])]
            let d = a - b
            if abs(d.x) < half.x && abs(d.y) < half.y {
                path.move(to: point(a)); path.addLine(to: point(b))
            }
            k += 2
        }
        ctx.stroke(path, with: .color(Color.ink.opacity(0.55)), lineWidth: max(1, 0.2 * s))
    }

    for trail in pic.paths where trail.count > 1 {
        var path = Path()
        path.addLines(trail.map(point))
        ctx.stroke(path, with: .color(Color.ochre.opacity(0.6)), lineWidth: 1)
    }

    // one path per bead color, so thousands of beads are only three fills
    if !pic.beads.isEmpty {
        let r = max(1, CGFloat(pic.radius) * s)
        var paths = [Path(), Path(), Path()]
        for i in pic.beads.indices {
            let c = point(pic.beads[i])
            let t = pic.types.isEmpty ? 0 : Int(pic.types[i])
            paths[t].addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        for t in 0..<3 { ctx.fill(paths[t], with: .color(beadColors[t])) }
    }
}

// Turn a grid of numbers into an image: low = cobalt, middle = dark, high = ochre.
func fieldImage(_ pic: Picture) -> CGImage? {
    let (lo, hi) = pic.fieldRange
    let low: (Float, Float, Float) = (127, 156, 255)
    let mid: (Float, Float, Float) = (20, 23, 27)
    let high: (Float, Float, Float) = (239, 164, 88)
    var bytes = [UInt8](repeating: 255, count: pic.nx * pic.ny * 4)
    for y in 0..<pic.ny {
        for x in 0..<pic.nx {
            let t = min(1, max(0, (pic.field[y * pic.nx + x] - lo) / (hi - lo)))
            let (a, b, f) = t < 0.5 ? (low, mid, t * 2) : (mid, high, t * 2 - 1)
            let o = ((pic.ny - 1 - y) * pic.nx + x) * 4   // image rows go top to bottom
            bytes[o] = UInt8(a.0 + (b.0 - a.0) * f)
            bytes[o + 1] = UInt8(a.1 + (b.1 - a.1) * f)
            bytes[o + 2] = UInt8(a.2 + (b.2 - a.2) * f)
        }
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
    return CGImage(width: pic.nx, height: pic.ny, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: pic.nx * 4, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

// A small line plot: data in cobalt, reference line in ochre.
struct CurveView: View {
    let curve: Curve

    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 4
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: size.height))
                p.addLine(to: CGPoint(x: size.width, y: size.height))
            }, with: .color(.rule), lineWidth: 1)
            guard curve.x.count > 1, let x0 = curve.x.first, let x1 = curve.x.last, x1 > x0 else { return }
            let all = curve.y + curve.reference
            let ymin = min(0, all.min() ?? 0), ymax = max((all.max() ?? 1) * 1.1, 1e-6)
            func pt(_ x: Float, _ y: Float) -> CGPoint {
                CGPoint(x: pad + CGFloat((x - x0) / (x1 - x0)) * (size.width - 2 * pad),
                        y: size.height - CGFloat((y - ymin) / (ymax - ymin)) * size.height)
            }
            if curve.reference.count == curve.x.count {
                var ref = Path()
                ref.addLines(curve.x.indices.map { pt(curve.x[$0], curve.reference[$0]) })
                ctx.stroke(ref, with: .color(.ochre), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            var line = Path()
            line.addLines(curve.x.indices.map { pt(curve.x[$0], curve.y[$0]) })
            ctx.stroke(line, with: .color(.cobalt), lineWidth: 1.5)
            ctx.draw(Text(String(format: "%.3g", ymax)).font(.mono(10)).foregroundColor(.muted),
                     at: CGPoint(x: 6, y: 2), anchor: .topLeading)
        }
        .overlay(alignment: .topLeading) {
            Text(curve.yLabel).font(.mono(10)).foregroundStyle(Color.muted).padding(.leading, 60)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(curve.xLabel).font(.mono(10)).foregroundStyle(Color.muted).padding(.bottom, 4)
        }
    }
}
