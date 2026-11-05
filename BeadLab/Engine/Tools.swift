import Foundation

// Small fast random number generator (SplitMix64). Seeded, so runs can be repeated.
struct Rng {
    var state: UInt64
    init(seed: UInt64 = 42) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        return hash64(state)
    }
    mutating func uniform() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
    // Normal distribution (Box-Muller)
    mutating func gauss() -> Float {
        let u = max(uniform(), 1e-7), v = uniform()
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }
    mutating func vec(_ box: Vec) -> Vec { Vec(uniform(), uniform()) * box }
}

@inline(__always) func hash64(_ x: UInt64) -> UInt64 {
    var z = x
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
}

// A random number that depends only on (a, b, step). DPD needs the same
// random force on both beads of a pair, even when two threads compute them.
@inline(__always) func pairNoise(_ i: Int, _ j: Int, _ step: Int) -> Float {
    let a = UInt64(min(i, j)), b = UInt64(max(i, j))
    let h = hash64((a << 32 | b) &+ hash64(UInt64(step)))
    let u = Float(h >> 40) / Float(1 << 24)   // 0..1
    return (u - 0.5) * 3.4641016             // uniform, unit variance
}

// Run body(i) for i in 0..<n on all CPU cores.
// Each i must only write to its own slot, never to another particle's.
func parallelFor(_ n: Int, _ body: (Int) -> Void) {
    let chunks = min(n, ProcessInfo.processInfo.activeProcessorCount * 4)
    if chunks <= 1 { for i in 0..<n { body(i) }; return }
    DispatchQueue.concurrentPerform(iterations: chunks) { c in
        for i in (n * c / chunks)..<(n * (c + 1) / chunks) { body(i) }
    }
}

// Cell list: split the periodic box into cells at least `cutoff` wide,
// so each particle only looks at the 9 cells around it instead of all N particles.
struct CellList {
    var nx = 1, ny = 1
    var size = Vec(1, 1)
    var head: [Int32] = []
    var next: [Int32] = []

    mutating func build(_ pos: [Vec], box: Vec, cutoff: Float) {
        nx = max(1, Int(box.x / cutoff)); ny = max(1, Int(box.y / cutoff))
        size = box / Vec(Float(nx), Float(ny))
        head = Array(repeating: -1, count: nx * ny)
        next = Array(repeating: -1, count: pos.count)
        for i in pos.indices {
            let c = cell(pos[i])
            next[i] = head[c]
            head[c] = Int32(i)
        }
    }

    func cell(_ p: Vec) -> Int {
        let cx = min(nx - 1, max(0, Int(p.x / size.x)))
        let cy = min(ny - 1, max(0, Int(p.y / size.y)))
        return cy * nx + cx
    }

    // Call body(j) for every particle j in the 3 x 3 cells around p (including p itself).
    // Needs at least 3 cells in each direction.
    func forEachNear(_ p: Vec, _ body: (Int) -> Void) {
        let cx = min(nx - 1, max(0, Int(p.x / size.x)))
        let cy = min(ny - 1, max(0, Int(p.y / size.y)))
        for dy in -1...1 {
            let y = (cy + dy + ny) % ny
            for dx in -1...1 {
                let x = (cx + dx + nx) % nx
                var j = head[y * nx + x]
                while j >= 0 {
                    body(Int(j))
                    j = next[Int(j)]
                }
            }
        }
    }
}
