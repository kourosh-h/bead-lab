import Foundation

typealias Vec = SIMD2<Float>

// A slider the screen shows for a simulation.
struct Param {
    let key: String
    let label: String
    let range: ClosedRange<Double>
    let step: Double
    var value: Double
    var resets = false  // changing it starts the run again
}

// A small line plot under the simulation.
struct Curve {
    var x: [Float] = []
    var y: [Float] = []
    var reference: [Float] = []  // optional second line, same x
    var xLabel = ""
    var yLabel = ""
}

// Everything the screen needs to draw one frame.
// Positions are in simulation units inside a box of size `box`.
struct Picture {
    var box = Vec(1, 1)
    var beads: [Vec] = []
    var types: [UInt8] = []      // 0 = cobalt, 1 = ochre, 2 = grey
    var radius: Float = 0.5
    var bonds: [Int32] = []      // pairs of bead indices: a0, b0, a1, b1, ...
    var paths: [[Vec]] = []      // free lines, e.g. particle trails
    var wall: Bool = false       // draw a surface at y = 0
    var field: [Float] = []      // grid values, row by row, from y = 0 up
    var nx = 0, ny = 0
    var fieldRange: (Float, Float) = (-1, 1)
    var curve = Curve()
}

protocol Simulation: AnyObject {
    var params: [Param] { get }
    var box: Vec { get }
    var info: String { get }
    func set(_ key: String, _ value: Double)
    func reset()
    func step()              // one frame worth of work
    func picture() -> Picture
    func touch(_ p: Vec)     // finger at p, in simulation units
}

extension Simulation {
    func touch(_ p: Vec) {}
}

// Keep the last n values of a time series.
struct History {
    var n = 300
    var values: [Float] = []
    mutating func add(_ v: Float) {
        values.append(v)
        if values.count > n { values.removeFirst(values.count - n) }
    }
}

// Minimum image in a periodic box.
@inline(__always) func wrapDelta(_ d: Vec, _ box: Vec) -> Vec {
    d - box * (d / box).rounded(.toNearestOrAwayFromZero)
}

@inline(__always) func wrapInto(_ p: Vec, _ box: Vec) -> Vec {
    p - box * (p / box).rounded(.down)
}

@inline(__always) func length2(_ d: Vec) -> Float { (d * d).sum() }
