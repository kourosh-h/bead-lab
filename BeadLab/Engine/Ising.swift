import Foundation

// 2D Ising model with Metropolis Monte Carlo. J = 1, kB = 1.
// Exact critical temperature: Tc = 2 / ln(1 + sqrt 2) = 2.269.
final class Ising: Simulation {
    let size = 192
    var params = [
        Param(key: "T", label: "temperature", range: 1...4, step: 0.01, value: 2.27),
        Param(key: "h", label: "field h", range: -0.5...0.5, step: 0.01, value: 0),
    ]
    var temperature: Float = 2.27
    var h: Float = 0
    var spin: [Int8] = []
    var rng = Rng()
    var sweeps = 0
    var history = History()

    var box: Vec { Vec(Float(size), Float(size)) }

    init() { reset() }

    func set(_ key: String, _ value: Double) {
        if key == "T" { temperature = Float(value) }
        if key == "h" { h = Float(value) }
    }

    func reset() {
        spin = (0..<size * size).map { _ in rng.uniform() < 0.5 ? 1 : -1 }
        sweeps = 0
        history = History()
    }

    func step() {
        let n = size
        for _ in 0..<2 {
            for _ in 0..<(n * n) {
                let x = Int(rng.next() % UInt64(n)), y = Int(rng.next() % UInt64(n))
                let s = Float(spin[y * n + x])
                let nb = Float(spin[y * n + (x + 1) % n]) + Float(spin[y * n + (x + n - 1) % n])
                       + Float(spin[((y + 1) % n) * n + x]) + Float(spin[((y + n - 1) % n) * n + x])
                let dE = 2 * s * (nb + h)   // energy change if we flip
                if dE <= 0 || rng.uniform() < exp(-dE / temperature) {
                    spin[y * n + x] = -spin[y * n + x]
                }
            }
            sweeps += 1
        }
        history.add(abs(magnetization))
    }

    var magnetization: Float { Float(spin.reduce(0) { $0 + Int($1) }) / Float(size * size) }

    var info: String {
        String(format: "%d x %d   T %.2f   m %+.3f   sweeps %d", size, size, temperature, magnetization, sweeps)
    }

    // Finger paints up spins.
    func touch(_ p: Vec) {
        let cx = Int(p.x), cy = Int(p.y)
        for y in (cy - 6)...(cy + 6) {
            for x in (cx - 6)...(cx + 6) where (x - cx) * (x - cx) + (y - cy) * (y - cy) < 36 {
                spin[((y + size) % size) * size + (x + size) % size] = 1
            }
        }
    }

    func picture() -> Picture {
        var pic = Picture(box: box)
        pic.field = spin.map { Float($0) }
        pic.nx = size; pic.ny = size
        let v = history.values
        pic.curve = Curve(x: v.indices.map { Float($0) }, y: v, xLabel: "frames (last 300)", yLabel: "|magnetization|")
        return pic
    }
}
