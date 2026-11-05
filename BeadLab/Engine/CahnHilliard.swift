import Foundation

// Cahn-Hilliard equation for a phase-separating mixture, c in [-1, 1]:
//   dc/dt = M lap(mu),   mu = c^3 - c - kappa lap(c)
// Explicit Euler on a periodic grid, dx = 1, M = 1, kappa = 1.
final class CahnHilliard: Simulation {
    let size = 128
    let dt: Float = 0.015
    let kappa: Float = 1
    var params = [
        Param(key: "c0", label: "mean composition", range: -0.6...0.6, step: 0.05, value: 0, resets: true),
    ]
    var c0: Float = 0
    var c: [Float] = [], mu: [Float] = []
    var rng = Rng()
    var time: Float = 0
    var growth: [Float] = [], times: [Float] = []
    var frame = 0

    var box: Vec { Vec(Float(size), Float(size)) }

    init() { reset() }

    func set(_ key: String, _ value: Double) {
        if key == "c0" { c0 = Float(value); reset() }
    }

    func reset() {
        c = (0..<size * size).map { _ in c0 + 0.1 * (rng.uniform() - 0.5) }
        mu = Array(repeating: 0, count: size * size)
        time = 0; frame = 0
        growth = []; times = []
    }

    // 5-point Laplacian with periodic wrap
    @inline(__always) func lap(_ f: UnsafeMutableBufferPointer<Float>, _ x: Int, _ y: Int) -> Float {
        let n = size
        let xp = (x + 1) % n, xm = (x + n - 1) % n, yp = (y + 1) % n, ym = (y + n - 1) % n
        return f[y * n + xp] + f[y * n + xm] + f[yp * n + x] + f[ym * n + x] - 4 * f[y * n + x]
    }

    func step() {
        let n = size
        for _ in 0..<30 {
            c.withUnsafeMutableBufferPointer { cb in
                mu.withUnsafeMutableBufferPointer { mb in
                    parallelFor(n) { y in
                        for x in 0..<n {
                            let v = cb[y * n + x]
                            mb[y * n + x] = v * v * v - v - kappa * lap(cb, x, y)
                        }
                    }
                    parallelFor(n) { y in
                        for x in 0..<n { cb[y * n + x] += dt * lap(mb, x, y) }
                    }
                }
            }
            time += dt
        }
        frame += 1
        if frame % 4 == 0 && times.count < 300 {
            times.append(time); growth.append(domainSize)
        }
    }

    // Domain size from the amount of interface: area / (number of unlike neighbour pairs)
    var domainSize: Float {
        let n = size
        var walls = 0
        for y in 0..<n {
            for x in 0..<n {
                let s = c[y * n + x] > 0
                if s != (c[y * n + (x + 1) % n] > 0) { walls += 1 }
                if s != (c[((y + 1) % n) * n + x] > 0) { walls += 1 }
            }
        }
        return walls == 0 ? Float(n) : 2 * Float(n * n) / Float(walls)
    }

    var info: String { String(format: "%d x %d   t %.0f   domain size %.1f", size, size, time, domainSize) }

    // Finger adds a drop of the second phase.
    func touch(_ p: Vec) {
        let cx = Int(p.x), cy = Int(p.y)
        for y in (cy - 5)...(cy + 5) {
            for x in (cx - 5)...(cx + 5) where (x - cx) * (x - cx) + (y - cy) * (y - cy) < 25 {
                c[((y + size) % size) * size + (x + size) % size] = 1
            }
        }
    }

    func picture() -> Picture {
        var pic = Picture(box: box)
        pic.field = c
        pic.nx = size; pic.ny = size
        // Lifshitz-Slyozov: domain size grows like t^(1/3)
        // reference line drawn through the latest point
        let ref = times.map { t -> Float in
            guard let t1 = times.last, let g1 = growth.last else { return 0 }
            return g1 * pow(t / t1, 1.0 / 3.0)
        }
        pic.curve = Curve(x: times, y: growth, reference: ref, xLabel: "t", yLabel: "domain size   (line: t^1/3)")
        return pic
    }
}
