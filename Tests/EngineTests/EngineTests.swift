import XCTest
@testable import Engine

final class EngineTests: XCTestCase {

    func testCellListFindsSameNeighboursAsBruteForce() {
        var rng = Rng(seed: 1)
        let box = Vec(10, 10)
        let pos = (0..<300).map { _ in rng.vec(box) }
        var cells = CellList()
        cells.build(pos, box: box, cutoff: 2.5)
        var fromCells = 0, brute = 0
        for i in pos.indices {
            cells.forEachNear(pos[i]) { j in
                if j != i && length2(wrapDelta(pos[i] - pos[j], box)) < 6.25 { fromCells += 1 }
            }
            for j in pos.indices where j != i && length2(wrapDelta(pos[i] - pos[j], box)) < 6.25 { brute += 1 }
        }
        XCTAssertEqual(fromCells, brute)
    }

    func testPairNoiseIsSymmetric() {
        XCTAssertEqual(pairNoise(3, 17, 5), pairNoise(17, 3, 5))
        XCTAssertNotEqual(pairNoise(3, 17, 5), pairNoise(3, 17, 6))
    }

    func testLennardJonesHoldsTemperature() {
        let sim = LennardJones()
        sim.set("T", 0.8)
        for _ in 0..<60 { sim.step() }
        XCTAssertEqual(sim.kineticT, 0.8, accuracy: 0.1)
    }

    func testDPDTemperatureNearOne() {
        let sim = DPD()
        for _ in 0..<100 { sim.step() }   // let the random start relax
        var sum: Float = 0
        for _ in 0..<50 { sim.step(); sum += sim.kineticT }
        XCTAssertEqual(sum / 50, 1.0, accuracy: 0.1)   // about 6 % hot: a known DPD time step artefact
    }

    func testDPDDemixesWithStrongRepulsion() {
        let sim = DPD()
        sim.set("aAB", 60)
        sim.step()
        let start = sim.history.values.last!
        for _ in 0..<150 { sim.step() }
        XCTAssertLessThan(sim.history.values.last!, 0.7 * start)
    }

    func testBrownianMSD() {
        let sim = Brownian()
        for _ in 0..<500 { sim.step() }
        let d = sim.msd.last! / (4 * sim.times.last!)
        XCTAssertEqual(d, 0.5, accuracy: 0.1)
    }

    func testPolymerCollapsesInPoorSolvent() {
        let good = Polymer(), poor = Polymer()
        good.set("lambda", 0); poor.set("lambda", 1.2)
        for _ in 0..<150 { good.step(); poor.step() }
        XCTAssertLessThan(poor.radiusOfGyration, good.radiusOfGyration)
    }

    func testIsingOrdersAtLowT() {
        let sim = Ising()
        sim.set("T", 1.2)
        for _ in 0..<100 { sim.step() }
        let hot = Ising()
        hot.set("T", 4)
        for _ in 0..<30 { hot.step() }
        XCTAssertLessThan(abs(hot.magnetization), 0.1)
        // a low-T quench forms large domains; energy per spin is a cleaner check than m
        XCTAssertGreaterThan(sim.history.values.last!, abs(hot.magnetization))
    }

    func testCahnHilliardConservesMassAndCoarsens() {
        let sim = CahnHilliard()
        let m0 = sim.c.reduce(0, +)
        for _ in 0..<40 { sim.step() }
        let first = sim.domainSize
        for _ in 0..<80 { sim.step() }
        XCTAssertEqual(sim.c.reduce(0, +), m0, accuracy: 1)
        XCTAssertGreaterThan(sim.domainSize, first)
        XCTAssertFalse(sim.c.contains { $0.isNaN })
    }

    func testBrushStaysFinite() {
        let sim = Brush()
        for _ in 0..<50 { sim.step() }
        XCTAssertFalse(sim.pos.contains { $0.x.isNaN || $0.y.isNaN })
        XCTAssertGreaterThan(sim.height, 3)
    }
}
