import SwiftUI

// Steps the simulation once per screen refresh. SwiftUI may redraw a view
// more than once per frame, so we only step when the frame time changes.
final class Runner {
    let sim: Simulation
    var lastFrame = Date.distantPast
    init(_ sim: Simulation) { self.sim = sim }

    func frame(at date: Date, running: Bool) -> Picture {
        if running && date != lastFrame {
            sim.step()
            lastFrame = date
        }
        return sim.picture()
    }
}

struct SimView: View {
    let entry: SimEntry
    @State private var runner: Runner
    @State private var values: [Double]
    @State private var running = true
    @State private var resets = 0   // bumping this redraws after a reset while paused

    init(entry: SimEntry, sim: Simulation) {
        self.entry = entry
        _runner = State(initialValue: Runner(sim))
        _values = State(initialValue: sim.params.map { $0.value })
    }

    var sim: Simulation { runner.sim }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.title).font(.display(30)).foregroundStyle(Color.ink)

                TimelineView(.animation(paused: !running)) { timeline in
                    let pic = runner.frame(at: timeline.date, running: running)
                    VStack(alignment: .leading, spacing: 8) {
                        canvas(pic)
                        Text(sim.info).font(.mono(11)).foregroundStyle(Color.muted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        CurveView(curve: pic.curve).frame(height: 120)
                    }
                    .id(resets)
                }

                buttons
                sliders
                Notes(entry: entry)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
    }

    func canvas(_ pic: Picture) -> some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(pic, in: &ctx, size: size) }
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let scale = Float(geo.size.width) / sim.box.x
                    // screen y points down, simulation y points up
                    let p = Vec(Float(g.location.x), Float(geo.size.height - g.location.y)) / scale
                    sim.touch(p)
                    if !running { resets += 1 }
                })
        }
        .aspectRatio(CGFloat(sim.box.x / sim.box.y), contentMode: .fit)
        .background(Color.paper)
        .overlay(Rectangle().stroke(Color.rule, lineWidth: 1))
    }

    var buttons: some View {
        HStack(spacing: 10) {
            Button(running ? "pause" : "play") { running.toggle() }
            Button("reset") { sim.reset(); resets += 1 }
            Spacer()
        }
        .buttonStyle(LabButton())
    }

    var sliders: some View {
        VStack(spacing: 10) {
            ForEach(sim.params.indices, id: \.self) { k in
                let p = sim.params[k]
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(p.label + (p.resets ? "  (restarts)" : ""))
                        Spacer()
                        Text(format(values[k], step: p.step)).foregroundStyle(Color.ink)
                    }
                    .font(.mono(12)).foregroundStyle(Color.muted)
                    Slider(value: $values[k], in: p.range, step: p.step, onEditingChanged: { editing in
                        // restarting runs only change once the finger lifts
                        if !editing || !p.resets {
                            sim.set(p.key, values[k]); resets += 1
                        }
                    })
                    .onChange(of: values[k]) { _, v in
                        if !p.resets { sim.set(p.key, v) }
                    }
                }
            }
        }
    }

    func format(_ v: Double, step: Double) -> String {
        step >= 1 ? String(Int(v)) : (step >= 0.05 ? String(format: "%.2f", v) : String(format: "%.3f", v))
    }
}

struct LabButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(13))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(configuration.isPressed ? Color.rule : Color.paper)
            .overlay(Rectangle().stroke(Color.rule, lineWidth: 1))
    }
}

// The three teaching paragraphs under every simulation.
struct Notes: View {
    let entry: SimEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            note("What you see", entry.what)
            note("The model", entry.model)
            note("Try this", entry.tryThis)
        }
        .padding(.top, 10)
    }

    func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.mono(11)).tracking(1).foregroundStyle(Color.ochre)
            Text(text).font(.system(size: 15)).foregroundStyle(Color.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
