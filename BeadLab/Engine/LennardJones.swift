import Foundation

// 2D Lennard-Jones fluid with a Langevin thermostat.
// Units: sigma = epsilon = mass = 1. Cutoff 2.5, cell lists, forces on all cores.
final class LennardJones: Simulation {
    let n = 1200
    let cutoff: Float = 2.5
    let dt: Float = 0.005
    let gamma: Float = 1.0
    let stepsPerFrame = 10

    var params = [
        Param(key: "T", label: "temperature", range: 0.1...1.5, step: 0.05, value: 0.45),
        Param(key: "rho", label: "density", range: 0.1...0.8, step: 0.05, value: 0.35, resets: true),
    ]
    var temperature: Float = 0.45
    var density: Float = 0.35

    private(set) var box = Vec(1, 1)
    var pos: [Vec] = [], vel: [Vec] = [], force: [Vec] = [], energy: [Float] = []
    var cells = CellList()
    var rng = Rng()
    var time: Float = 0
    var rdf = [Float](repeating: 0, count: 50)

    init() { reset() }

    func set(_ key: String, _ value: Double) {
        if key == "T" { temperature = Float(value) }
        if key == "rho" { density = Float(value); reset() }
    }

    func reset() {
        let side = (Float(n) / density).squareRoot()
        box = Vec(side, side)
        // start on a square lattice so no two atoms overlap
        let k = Int(Float(n).squareRoot().rounded(.up))
        let a = side / Float(k)
        pos = (0..<n).map { i in Vec(Float(i % k) + 0.5, Float(i / k) + 0.5) * a }
        vel = (0..<n).map { _ in Vec(rng.gauss(), rng.gauss()) * temperature.squareRoot() }
        force = Array(repeating: .zero, count: n)
        energy = Array(repeating: 0, count: n)
        rdf = rdf.map { _ in 0 }
        time = 0
        computeForces()
    }

    func computeForces() {
        cells.build(pos, box: box, cutoff: cutoff)
        let rc2 = cutoff * cutoff
        let shift = 4 * (pow(cutoff, -12) - pow(cutoff, -6))
        // local copies: reading these inside the parallel loop is much faster than reading self.pos etc.
        let pos = self.pos, box = self.box, cells = self.cells
        force.withUnsafeMutableBufferPointer { f in
            energy.withUnsafeMutableBufferPointer { e in
                parallelFor(n) { i in
                    var fi = Vec.zero, ei: Float = 0
                    cells.forEachNear(pos[i]) { j in
                        if j == i { return }
                        let d = wrapDelta(pos[i] - pos[j], box)
                        let r2 = length2(d)
                        if r2 >= rc2 { return }
                        let inv2 = 1 / r2, inv6 = inv2 * inv2 * inv2
                        fi += d * (24 * inv2 * inv6 * (2 * inv6 - 1))
                        ei += 0.5 * (4 * inv6 * (inv6 - 1) - shift)  // half, each pair is seen twice
                    }
                    f[i] = fi
                    e[i] = ei
                }
            }
        }
    }

    func step() {
        let kick = (2 * gamma * temperature * dt).squareRoot()
        for _ in 0..<stepsPerFrame {
            // velocity Verlet, with friction and random kicks added to the velocity (Langevin)
            for i in 0..<n {
                vel[i] += 0.5 * dt * force[i]
                pos[i] = wrapInto(pos[i] + dt * vel[i], box)
            }
            computeForces()
            for i in 0..<n {
                vel[i] += 0.5 * dt * force[i]
                vel[i] += -gamma * dt * vel[i] + kick * Vec(rng.gauss(), rng.gauss())
            }
            time += dt
        }
        sampleRDF()
    }

    // Radial distribution function g(r), smoothed over time.
    func sampleRDF() {
        let bins = rdf.count, dr = cutoff / Float(bins)
        var counts = [Float](repeating: 0, count: bins)
        for i in 0..<n {
            cells.forEachNear(pos[i]) { j in
                if j == i { return }
                let r = length2(wrapDelta(pos[i] - pos[j], box)).squareRoot()
                let b = Int(r / dr)
                if b < bins { counts[b] += 1 }
            }
        }
        let rho = Float(n) / (box.x * box.y)
        for b in 0..<bins {
            let r = (Float(b) + 0.5) * dr
            let g = counts[b] / (Float(n) * rho * 2 * .pi * r * dr)
            rdf[b] += 0.1 * (g - rdf[b])
        }
    }

    var kineticT: Float { vel.reduce(0) { $0 + length2($1) } / Float(2 * n) }

    var info: String {
        let pe = energy.reduce(0, +) / Float(n)
        return String(format: "N %d   T %.2f   E_pot/N %.2f   t %.0f", n, kineticT, pe, time)
    }

    // Finger heats the atoms under it.
    func touch(_ p: Vec) {
        for i in 0..<n where length2(wrapDelta(pos[i] - p, box)) < 9 {
            vel[i] += Vec(rng.gauss(), rng.gauss()) * 1.5
        }
    }

    func picture() -> Picture {
        var pic = Picture(box: box, beads: pos, radius: 0.5)
        // fast atoms in ochre, the rest in cobalt
        pic.types = vel.map { length2($0) > 4 * temperature ? 1 : 0 }
        let dr = cutoff / Float(rdf.count)
        pic.curve = Curve(x: rdf.indices.map { (Float($0) + 0.5) * dr }, y: rdf,
                          reference: rdf.map { _ in 1 }, xLabel: "r / σ", yLabel: "g(r)")
        return pic
    }
}
