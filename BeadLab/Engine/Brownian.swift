import Foundation

// Free Brownian particles: x(t + dt) = x(t) + sqrt(2 D dt) * noise.
// The mean squared displacement should follow MSD = 4 D t in 2D.
final class Brownian: Simulation {
    let n = 400
    let dt: Float = 0.05
    let box = Vec(60, 60)
    var params = [Param(key: "D", label: "diffusion D", range: 0.1...2, step: 0.1, value: 0.5, resets: true)]
    var d: Float = 0.5

    var start: [Vec] = [], pos: [Vec] = []   // unwrapped positions
    var trails: [[Vec]] = []
    var msd: [Float] = [], times: [Float] = []
    var rng = Rng()
    var time: Float = 0
    var frame = 0

    init() { reset() }

    func set(_ key: String, _ value: Double) {
        if key == "D" { d = Float(value); reset() }
    }

    func reset() {
        pos = (0..<n).map { _ in rng.vec(box) }
        start = pos
        trails = (0..<4).map { [pos[$0]] }
        msd = [0]; times = [0]; time = 0; frame = 0
    }

    func step() {
        let s = (2 * d * dt).squareRoot()
        for _ in 0..<4 {
            for i in 0..<n { pos[i] += s * Vec(rng.gauss(), rng.gauss()) }
            time += dt
        }
        frame += 1
        for k in trails.indices {
            trails[k].append(pos[k])
            if trails[k].count > 400 { trails[k].removeFirst() }
        }
        if frame % 5 == 0 && times.count < 300 {
            var sum: Float = 0
            for i in 0..<n { sum += length2(pos[i] - start[i]) }
            msd.append(sum / Float(n)); times.append(time)
        }
    }

    var info: String {
        let fit = time > 0 ? (msd.last ?? 0) / (4 * (times.last ?? 1)) : 0
        return String(format: "N %d   t %.0f   D from MSD %.2f (set %.2f)", n, time, fit, d)
    }

    func picture() -> Picture {
        var pic = Picture(box: box, radius: 0.5)
        pic.beads = pos.map { wrapInto($0, box) }
        pic.types = (0..<n).map { $0 < trails.count ? 1 : 0 }
        // trails are unwrapped; shift each so its newest point sits on its bead
        pic.paths = trails.map { t in
            let shift = wrapInto(t.last!, box) - t.last!
            return t.map { $0 + shift }
        }
        pic.curve = Curve(x: times, y: msd, reference: times.map { 4 * d * $0 },
                          xLabel: "t", yLabel: "MSD   (line: 4Dt)")
        return pic
    }
}
