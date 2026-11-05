import SwiftUI

struct HomeView: View {
    // Launching with "-screen dpd" opens that simulation directly (used for screenshots).
    @State private var path: [String] = {
        let args = ProcessInfo.processInfo.arguments
        if let k = args.firstIndex(of: "-screen"), k + 1 < args.count { return [args[k + 1]] }
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ForEach(groups, id: \.self) { group in
                        Text(group.uppercased())
                            .font(.mono(11)).tracking(1).foregroundStyle(Color.muted)
                            .padding(.top, 32).padding(.bottom, 6)
                        Rectangle().fill(Color.ink).frame(height: 1.5)
                        ForEach(catalog.filter { $0.group == group }) { entry in
                            NavigationLink(value: entry.id) { row(entry) }
                                .buttonStyle(.plain)
                        }
                    }
                    Text("Kourosh Hasheminejad · computational materials science")
                        .font(.mono(11)).foregroundStyle(Color.muted)
                        .padding(.top, 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.ground)
            .navigationDestination(for: String.self) { id in
                let entry = catalog.first { $0.id == id }!
                if let sim = entry.make() {
                    SimView(entry: entry, sim: sim)
                } else {
                    GrayScottScreen(entry: entry)
                }
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiblockMark().frame(height: 18).padding(.top, 24)
            Text("Bead Lab").font(.display(44)).foregroundStyle(Color.ink)
            Text("Simulations from molecular dynamics, soft matter and pattern formation, running live on your phone. Each one comes with the model behind it.")
                .font(.system(size: 16)).foregroundStyle(Color.muted)
        }
    }

    func row(_ entry: SimEntry) -> some View {
        let number = catalog.firstIndex { $0.id == entry.id }! + 1
        return HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(String(format: "%02d", number)).font(.mono(13)).foregroundStyle(Color.ochre)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.display(21)).foregroundStyle(Color.ink)
                Text(entry.meta).font(.mono(11)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1) }
        .contentShape(Rectangle())
    }
}

// A short A-B diblock chain, drawn as the app's mark.
struct DiblockMark: View {
    var body: some View {
        Canvas { ctx, size in
            let r = size.height / 2
            let n = 8
            var bond = Path()
            bond.move(to: CGPoint(x: r, y: r))
            bond.addLine(to: CGPoint(x: r + CGFloat(n - 1) * 1.7 * r, y: r))
            ctx.stroke(bond, with: .color(.muted), lineWidth: 1.5)
            for k in 0..<n {
                let c = CGPoint(x: r + CGFloat(k) * 1.7 * r, y: r)
                let bead = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(bead, with: .color(k < n / 2 ? .cobalt : .ochre))
            }
        }
    }
}
