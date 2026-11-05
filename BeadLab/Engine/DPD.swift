import Foundation

// Dissipative particle dynamics (Groot and Warren 1997) in 2D.
// Two bead types A and B. Chain length 1 gives a binary blend,
// longer chains give A-B diblock copolymers.
// F = a w e  -  gamma w^2 (e . v) e  +  sigma w theta / sqrt(dt) e,   w = 1 - r,  r < 1
final class DPD: Simulation {
    let a: Float = 25          // same-type repulsion
    let gamma: Float = 4.5
    let sigma: Float = 3       // sigma^2 = 2 gamma kT, kT = 1
    let kBond: Float = 4       // harmonic bond, rest length 0
    let dt: Float = 0.03
    let density: Float = 4
    let box = Vec(36, 36)

    var params = [
        Param(key: "aAB", label: "A-B repulsion", range: 25...60, step: 1, value: 40),
        Param(key: "len", label: "chain length", range: 1...12, step: 1, value: 1, resets: true),
        Param(key: "fA", label: "fraction A", range: 0.2...0.8, step: 0.05, value: 0.5, resets: true),
    ]
    var aAB: Float = 40
    var chain = 1
    var fractionA: Float = 0.5
    var stepsPerFrame = 4

    var n = 0
    var pos: [Vec] = [], vel: [Vec] = [], force: [Vec] = []
    var type: [UInt8] = []
    var bonds: [Int32] = []
    var contacts: [Float] = []   // A-B neighbours of each bead
    var cells = CellList()
    var rng = Rng()
    var stepCount = 0
    var history = History()

    init() { reset() }

    func set(_ key: String, _ value: Double) {
        switch key {
        case "aAB": aAB = Float(value)
        case "len": chain = Int(value); reset()
        case "fA": fractionA = Float(value); reset()
        default: break
        }
    }

    func reset() {
        let chains = Int(density * box.x * box.y) / chain
        n = chains * chain
        pos = []; type = []; bonds = []
        let nA = Int((fractionA * Float(chain)).rounded())
        for c in 0..<chains {
            // each chain is a short random walk; in a blend each bead picks its type at random
            var p = rng.vec(box)
            for k in 0..<chain {
                if k > 0 {
                    p = wrapInto(p + 0.5 * Vec(rng.gauss(), rng.gauss()), box)
                    bonds += [Int32(c * chain + k - 1), Int32(c * chain + k)]
                }
                pos.append(p)
                let isA = chain == 1 ? rng.uniform() < fractionA : k < nA
                type.append(isA ? 0 : 1)
            }
        }
        vel = Array(repeating: .zero, count: n)
        force = Array(repeating: .zero, count: n)
        contacts = Array(repeating: 0, count: n)
        history = History()
        stepCount = 0
        computeForces()
    }

    func computeForces() {
        cells.build(pos, box: box, cutoff: 1)
        let noise = sigma / dt.squareRoot()
        let s = stepCount, a = self.a, aAB = self.aAB, gamma = self.gamma
        // local copies: much faster to read inside the parallel loop than self.pos etc.
        let pos = self.pos, vel = self.vel, type = self.type, box = self.box, cells = self.cells
        force.withUnsafeMutableBufferPointer { f in
            contacts.withUnsafeMutableBufferPointer { c in
                parallelFor(n) { i in
                    var fi = Vec.zero, ab: Float = 0
                    cells.forEachNear(pos[i]) { j in
                        if j == i { return }
                        let d = wrapDelta(pos[i] - pos[j], box)
                        let r2 = length2(d)
                        if r2 >= 1 || r2 == 0 { return }
                        let r = r2.squareRoot(), e = d / r, w = 1 - r
                        let aij: Float
                        if type[i] == type[j] { aij = a } else { aij = aAB; ab += 1 }
                        let ev = (e * (vel[i] - vel[j])).sum()
                        // conservative, dissipative and random parts, split so the compiler is fast
                        let fc: Float = aij * w
                        let fd: Float = gamma * w * w * ev
                        let fr: Float = noise * w * pairNoise(i, j, s)
                        fi += (fc - fd + fr) * e
                    }
                    f[i] = fi
                    c[i] = ab
                }
            }
        }
        // bonds are few, so add them on one core
        var k = 0
        while k < bonds.count {
            let i = Int(bonds[k]), j = Int(bonds[k + 1])
            let fb = -kBond * wrapDelta(self.pos[i] - self.pos[j], box)
            force[i] += fb; force[j] -= fb
            k += 2
        }
    }

    func step() {
        for _ in 0..<stepsPerFrame {
            // velocity Verlet; forces use the half-step velocity (Groot-Warren, lambda = 0.5)
            for i in 0..<n {
                vel[i] += 0.5 * dt * force[i]
                pos[i] = wrapInto(pos[i] + dt * vel[i], box)
            }
            stepCount += 1
            computeForces()
            for i in 0..<n { vel[i] += 0.5 * dt * force[i] }
        }
        history.add(contacts.reduce(0, +) / Float(n))
    }

    var kineticT: Float { vel.reduce(0) { $0 + length2($1) } / Float(2 * n) }

    var info: String {
        String(format: "%d beads   kT %.2f   t %.0f", n, kineticT, Float(stepCount) * dt)
    }

    // Finger pushes beads out of the way, like stirring.
    func touch(_ p: Vec) {
        for i in 0..<n {
            let d = wrapDelta(pos[i] - p, box)
            let r2 = length2(d)
            if r2 < 4 && r2 > 0 { vel[i] += 3 * d / r2.squareRoot() }
        }
    }

    func picture() -> Picture {
        var pic = Picture(box: box, beads: pos, types: type, radius: 0.32, bonds: bonds)
        let h = history.values
        pic.curve = Curve(x: h.indices.map { Float($0) * Float(stepsPerFrame) * dt }, y: h,
                          xLabel: "time (last 300 frames)", yLabel: "A-B contacts per bead")
        return pic
    }
}
