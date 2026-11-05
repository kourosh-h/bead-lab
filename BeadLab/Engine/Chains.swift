import Foundation

// Shared physics for the two polymer simulations: bead-spring chains in implicit solvent.
// Non-bonded beads feel WCA repulsion plus an attraction of strength lambda:
//   lambda = 0 is a good solvent (chains swell), lambda ~ 1 is a poor solvent (chains collapse).
// Bonds are stiff harmonic springs with rest length 1.
// Motion is Langevin dynamics at kT = 1.
class BeadSpring {
    var pos: [Vec] = [], vel: [Vec] = [], force: [Vec] = []
    var bonds: [Int32] = []
    var fixed: [Bool] = []        // grafted beads do not move
    var lambda: Float = 0.3
    var kBond: Float = 200
    var gamma: Float = 1
    let dt: Float = 0.005
    var rng = Rng()
    var steps = 0

    // Extra force on bead i (for example a wall). Override in subclasses.
    func external(_ i: Int) -> Vec { .zero }
    func wrap(_ d: Vec) -> Vec { d }
    func place(_ p: Vec) -> Vec { p }

    func computeForces() {
        let n = pos.count
        let rmin2: Float = pow(2, 1.0 / 3.0)   // (2^(1/6))^2, the LJ minimum
        let rc2: Float = 2.5 * 2.5
        let pos = self.pos, lambda = self.lambda   // local copies, faster in the loop
        let ext = pos.indices.map { external($0) }
        force.withUnsafeMutableBufferPointer { f in
            parallelFor(n) { i in
                var fi = ext[i]
                for j in 0..<n where j != i {
                    let d = wrap(pos[i] - pos[j])
                    let r2 = length2(d)
                    if r2 >= rc2 { continue }
                    let inv2 = 1 / r2, inv6 = inv2 * inv2 * inv2
                    let lj = 24 * inv2 * inv6 * (2 * inv6 - 1)   // full LJ force / r
                    // WCA part always, attractive part scaled by lambda
                    fi += d * (r2 < rmin2 ? lj : lambda * lj)
                }
                f[i] = fi
            }
        }
        var k = 0
        while k < bonds.count {
            let i = Int(bonds[k]), j = Int(bonds[k + 1])
            let d = wrap(self.pos[i] - self.pos[j])
            let r = length2(d).squareRoot()
            let fb = -kBond * (r - 1) * d / r
            force[i] += fb; force[j] -= fb
            k += 2
        }
    }

    func advance(_ count: Int) {
        let kick = (2 * gamma * dt).squareRoot()
        for _ in 0..<count {
            for i in pos.indices where !fixed[i] {
                vel[i] += 0.5 * dt * force[i]
                pos[i] = place(pos[i] + dt * vel[i])
            }
            computeForces()
            for i in pos.indices where !fixed[i] {
                vel[i] += 0.5 * dt * force[i]
                vel[i] += -gamma * dt * vel[i] + kick * Vec(rng.gauss(), rng.gauss())
            }
            steps += 1
        }
    }
}

// One chain, free in space. Coil-to-globule transition.
final class Polymer: BeadSpring, Simulation {
    let n = 80
    let box = Vec(40, 40)
    var params = [Param(key: "lambda", label: "attraction", range: 0...1.5, step: 0.05, value: 0.2)]
    var history = History()

    override init() { super.init(); reset() }

    func set(_ key: String, _ value: Double) {
        if key == "lambda" { lambda = Float(value) }
    }

    func reset() {
        // start as a random walk that never steps back onto itself
        pos = [.zero]
        var tries = 0
        while pos.count < n {
            let angle = 2 * Float.pi * rng.uniform()
            let p = pos.last! + Vec(cos(angle), sin(angle))
            if pos.allSatisfy({ length2($0 - p) > 0.8 }) { pos.append(p) }
            tries += 1
            if tries > 10000 { pos = [.zero]; tries = 0 }   // walked into a dead end, start over
        }
        vel = Array(repeating: .zero, count: n)
        force = Array(repeating: .zero, count: n)
        fixed = Array(repeating: false, count: n)
        bonds = (1..<n).flatMap { [Int32($0 - 1), Int32($0)] }
        history = History()
        steps = 0
        computeForces()
    }

    func step() {
        advance(40)
        history.add(radiusOfGyration)
    }

    var center: Vec { pos.reduce(.zero, +) / Float(n) }

    var radiusOfGyration: Float {
        let c = center
        return (pos.reduce(0) { $0 + length2($1 - c) } / Float(n)).squareRoot()
    }

    var info: String {
        String(format: "%d beads   attraction %.2f   Rg %.1f", n, lambda, radiusOfGyration)
    }

    func picture() -> Picture {
        let shift = 0.5 * box - center
        var pic = Picture(box: box, beads: pos.map { $0 + shift }, radius: 0.5, bonds: bonds)
        pic.types = (0..<n).map { $0 == 0 || $0 == n - 1 ? 1 : 0 }   // ends in ochre
        let h = history.values
        pic.curve = Curve(x: h.indices.map { Float($0) }, y: h,
                          xLabel: "frames (last 300)", yLabel: "radius of gyration")
        return pic
    }
}

// Chains grafted to a flat surface at y = 0, periodic in x. A polymer brush, as in a coating.
final class Brush: BeadSpring, Simulation {
    let length = 16
    let box = Vec(40, 30)
    var params = [
        Param(key: "chains", label: "chains grafted", range: 4...32, step: 1, value: 14, resets: true),
        Param(key: "lambda", label: "attraction", range: 0...1.5, step: 0.05, value: 0.2),
    ]
    var chains = 14
    var profile = [Float](repeating: 0, count: 30)

    override init() { super.init(); reset() }

    func set(_ key: String, _ value: Double) {
        if key == "chains" { chains = Int(value); reset() }
        if key == "lambda" { lambda = Float(value) }
    }

    override func wrap(_ d: Vec) -> Vec { Vec(d.x - box.x * (d.x / box.x).rounded(), d.y) }
    override func place(_ p: Vec) -> Vec { Vec(p.x - box.x * (p.x / box.x).rounded(.down), p.y) }

    // soft wall: push beads up when they come below y = 1
    override func external(_ i: Int) -> Vec {
        let y = pos[i].y
        return y < 1 ? Vec(0, 50 * (1 - y)) : .zero
    }

    func reset() {
        pos = []; bonds = []; fixed = []
        let spacing = box.x / Float(chains)
        for c in 0..<chains {
            for k in 0..<length {
                pos.append(Vec((Float(c) + 0.5) * spacing, 0.6 + Float(k) * 0.97))
                fixed.append(k == 0)
                if k > 0 { bonds += [Int32(c * length + k - 1), Int32(c * length + k)] }
            }
        }
        vel = Array(repeating: .zero, count: pos.count)
        force = Array(repeating: .zero, count: pos.count)
        profile = profile.map { _ in 0 }
        steps = 0
        computeForces()
    }

    func step() {
        advance(20)
        // bead density against height, smoothed over time
        var counts = [Float](repeating: 0, count: profile.count)
        for p in pos {
            let b = Int(p.y)
            if b >= 0 && b < counts.count { counts[b] += 1 }
        }
        for b in profile.indices {
            profile[b] += 0.05 * (counts[b] / box.x - profile[b])
        }
    }

    var height: Float {
        // mean height of the free chain ends
        let ends = (0..<chains).map { pos[$0 * length + length - 1].y }
        return ends.reduce(0, +) / Float(chains)
    }

    var info: String {
        String(format: "%d chains of %d   grafting %.2f /σ   end height %.1f",
               chains, length, Float(chains) / box.x, height)
    }

    func picture() -> Picture {
        var pic = Picture(box: box, beads: pos, radius: 0.5, bonds: bonds)
        pic.types = (0..<pos.count).map { $0 % length == 0 ? 2 : ($0 % length == length - 1 ? 1 : 0) }
        pic.wall = true
        pic.curve = Curve(x: profile.indices.map { Float($0) + 0.5 }, y: profile,
                          xLabel: "height above surface", yLabel: "bead density")
        return pic
    }
}
