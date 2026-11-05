import Foundation

// The list of simulations shown on the home screen, with the teaching text for each.
struct SimEntry: Identifiable {
    let id: String
    let title: String
    let group: String
    let meta: String        // one line under the title
    let what: String        // what you see
    let model: String       // the physics, in a few lines
    let tryThis: String
    let make: () -> Simulation?   // nil for the GPU simulation, which has its own view
}

let groups = ["Molecules", "Polymers and soft matter", "Fields and patterns"]

let catalog: [SimEntry] = [
    SimEntry(
        id: "lj", title: "Lennard-Jones fluid", group: "Molecules",
        meta: "molecular dynamics · 1200 atoms · all CPU cores",
        what: "Atoms that attract at medium range and repel up close. At low temperature they condense into liquid drops and crystals, at high temperature they form a gas. Fast atoms are drawn in ochre. The plot is the radial distribution function g(r): peaks mean neighbours sit at preferred distances.",
        model: "V(r) = 4ε[(σ/r)¹² − (σ/r)⁶], cut at 2.5σ. Velocity Verlet with a Langevin thermostat, dt = 0.005. A cell list means each atom only checks nearby cells, so the cost grows like N, not N².",
        tryThis: "Drop the temperature to 0.2 and watch drops form, then raise it past 1. Touch the screen to heat a spot.",
        make: { LennardJones() }),
    SimEntry(
        id: "brown", title: "Brownian motion and diffusion", group: "Molecules",
        meta: "random walks · 400 particles · MSD against 4Dt",
        what: "Particles kicked around by an invisible solvent. Four of them leave trails. The plot shows the mean squared displacement, which grows in a straight line: that line's slope is how a diffusion coefficient is measured from any MD run.",
        model: "Overdamped Langevin: x(t+dt) = x(t) + √(2D dt) ξ, with ξ a standard normal number. In 2D, MSD(t) = 4Dt.",
        tryThis: "Change D and see the slope change. The info line fits D back from the MSD.",
        make: { Brownian() }),
    SimEntry(
        id: "dpd", title: "DPD blends and diblock copolymers", group: "Polymers and soft matter",
        meta: "dissipative particle dynamics · 5184 beads · all CPU cores",
        what: "Two bead types, A (cobalt) and B (ochre). As single beads they demix into large domains, like oil and water. Bond them into A-B chains and they cannot separate fully, so they form stripes and droplets a few beads wide: microphase separation, the basis of many coatings and block copolymer materials.",
        model: "Groot-Warren DPD: soft repulsion a(1 − r), friction and random forces that together act as a thermostat, cutoff 1, density 4, kT = 1. a_AA = a_BB = 25. The random force for each pair is built from a hash of the pair and the time step, so both beads get the same kick even on different CPU cores.",
        tryThis: "Set chain length 1 and A-B repulsion 50. Then chain length 8 with fraction A 0.5, then 0.25. Touch to stir.",
        make: { DPD() }),
    SimEntry(
        id: "coil", title: "Polymer coil and globule", group: "Polymers and soft matter",
        meta: "bead-spring chain · implicit solvent · radius of gyration",
        what: "One chain of 80 beads. In a good solvent it swells into a loose coil. When the beads attract each other (a poor solvent) the chain collapses into a dense globule. The ends are in ochre.",
        model: "WCA repulsion between all beads plus the attractive part of Lennard-Jones scaled by λ. Stiff harmonic bonds of length 1. Langevin dynamics at kT = 1.",
        tryThis: "Move attraction from 0 to 1.2 and back, and watch the radius of gyration.",
        make: { Polymer() }),
    SimEntry(
        id: "brush", title: "Polymer brush on a surface", group: "Polymers and soft matter",
        meta: "grafted chains · coating model · density profile",
        what: "Chains with one end fixed to a surface (grey beads). Few chains lie as separate mushrooms. Crowd them and they push each other upward into a brush. A poor solvent makes the brush collapse onto the surface. The plot is bead density against height.",
        model: "Same bead-spring model as the coil, periodic along the surface, a soft wall at y = 0, grafted beads held fixed.",
        tryThis: "Graft 6 chains, then 30. With 30 chains, raise the attraction above 1.",
        make: { Brush() }),
    SimEntry(
        id: "ising", title: "Ising model", group: "Fields and patterns",
        meta: "Monte Carlo · 192 × 192 spins · phase transition at 2.27",
        what: "A grid of up and down spins that like to align with their neighbours. Below the critical temperature large domains grow, above it the spins stay disordered. Right at 2.27 you get domains of every size.",
        model: "E = −Σ s_i s_j − h Σ s_i. Metropolis: flip a random spin if the energy drops, or with probability exp(−ΔE/T) if it rises.",
        tryThis: "Start at 2.27, then go to 1.5 and 3.5. Add a small field h. Touch to paint up spins.",
        make: { Ising() }),
    SimEntry(
        id: "ch", title: "Cahn-Hilliard phase separation", group: "Fields and patterns",
        meta: "continuum model · 128 × 128 grid · coarsening t^1/3",
        what: "The continuum version of the DPD blend. A mixed state splits into two phases (spinodal decomposition), then the domains slowly grow. The plot follows the domain size, which should grow like t^1/3.",
        model: "∂c/∂t = ∇²(c³ − c − κ∇²c), explicit Euler, periodic grid. The total amount of each phase is conserved.",
        tryThis: "Mean composition 0 gives stripes that merge, 0.4 gives droplets. Touch to add a drop.",
        make: { CahnHilliard() }),
    SimEntry(
        id: "gs", title: "Gray-Scott patterns on the GPU", group: "Fields and patterns",
        meta: "reaction-diffusion · 512 × 512 · Metal compute shader",
        what: "Two chemicals that react and diffuse. Depending on the feed and kill rates you get spots that divide, worms, mazes or coral. The grid is updated by the phone's GPU, thousands of cells in parallel.",
        model: "∂u/∂t = D_u∇²u − uv² + F(1 − u),  ∂v/∂t = D_v∇²v + uv² − (F + k)v. Each GPU thread updates one grid cell, 16 times per frame.",
        tryThis: "Try the presets, then draw on the screen to seed new patterns.",
        make: { nil }),
]
