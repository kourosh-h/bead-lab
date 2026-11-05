import SwiftUI
import MetalKit

// Must match Params in GrayScott.metal
struct GrayScottParams {
    var feed: Float
    var kill: Float
    var touch: SIMD2<Float>
    var radius: Float
    var pad: Int32 = 0
}

// Runs Gray-Scott on the GPU. Two textures hold the grid; each step reads one and writes the other.
final class GrayScottRenderer: NSObject, MTKViewDelegate {
    let size = 512
    let stepsPerFrame = 16
    let device: MTLDevice
    let queue: MTLCommandQueue
    let stepPipeline: MTLComputePipelineState
    let showPipeline: MTLComputePipelineState
    var a: MTLTexture, b: MTLTexture

    var feed: Float = 0.0545
    var kill: Float = 0.062
    var running = true
    var touch: SIMD2<Float>? = nil   // set by the finger, used once

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let stepFn = library.makeFunction(name: "grayScottStep"),
              let showFn = library.makeFunction(name: "grayScottShow"),
              let step = try? device.makeComputePipelineState(function: stepFn),
              let show = try? device.makeComputePipelineState(function: showFn)
        else { return nil }
        self.device = device
        self.queue = queue
        stepPipeline = step
        showPipeline = show

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: size, height: size, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        guard let ta = device.makeTexture(descriptor: desc), let tb = device.makeTexture(descriptor: desc) else { return nil }
        a = ta; b = tb
        super.init()
        reset()
    }

    // u = 1 everywhere, with a few random squares of v to start patterns
    func reset() {
        var cells = [Float](repeating: 0, count: size * size * 2)
        for i in 0..<(size * size) { cells[2 * i] = 1 }
        for _ in 0..<20 {
            let cx = Int.random(in: 20..<(size - 20)), cy = Int.random(in: 20..<(size - 20))
            for y in (cy - 6)..<(cy + 6) {
                for x in (cx - 6)..<(cx + 6) {
                    cells[2 * (y * size + x)] = 0.5
                    cells[2 * (y * size + x) + 1] = 0.25
                }
            }
        }
        cells.withUnsafeBytes { raw in
            a.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0,
                      withBytes: raw.baseAddress!, bytesPerRow: size * 2 * MemoryLayout<Float>.size)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeComputeCommandEncoder() else { return }
        let group = MTLSize(width: 16, height: 16, depth: 1)

        if running {
            var p = GrayScottParams(feed: feed, kill: kill, touch: touch ?? .zero, radius: touch == nil ? 0 : 10)
            touch = nil
            encoder.setComputePipelineState(stepPipeline)
            for k in 0..<stepsPerFrame {
                if k == 1 { p.radius = 0 }
                encoder.setTexture(a, index: 0)
                encoder.setTexture(b, index: 1)
                encoder.setBytes(&p, length: MemoryLayout<GrayScottParams>.stride, index: 0)
                encoder.dispatchThreads(MTLSize(width: size, height: size, depth: 1), threadsPerThreadgroup: group)
                (a, b) = (b, a)
            }
        }

        encoder.setComputePipelineState(showPipeline)
        encoder.setTexture(a, index: 0)
        encoder.setTexture(drawable.texture, index: 1)
        let out = drawable.texture
        encoder.dispatchThreads(MTLSize(width: out.width, height: out.height, depth: 1), threadsPerThreadgroup: group)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}

// Wraps the Metal view so SwiftUI can show it.
struct MetalGrid: UIViewRepresentable {
    let renderer: GrayScottRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.framebufferOnly = false        // the compute shader writes straight into the screen texture
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.delegate = renderer
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}
}

struct GrayScottScreen: View {
    let entry: SimEntry
    @State private var renderer = MTLCreateSystemDefaultDevice().flatMap { GrayScottRenderer(device: $0) }
    @State private var feed = 0.0545
    @State private var kill = 0.062
    @State private var running = true

    let presets: [(String, Double, Double)] = [
        ("coral", 0.0545, 0.062), ("spots", 0.0367, 0.0649), ("worms", 0.078, 0.061), ("maze", 0.029, 0.057),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.title).font(.display(30)).foregroundStyle(Color.ink)
                if let renderer {
                    GeometryReader { geo in
                        MetalGrid(renderer: renderer)
                            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                                let s = Float(renderer.size) / Float(geo.size.width)
                                // texture row 0 is the top of the screen, same as SwiftUI
                                renderer.touch = SIMD2(Float(g.location.x), Float(g.location.y)) * s
                            })
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Rectangle().stroke(Color.rule, lineWidth: 1))

                    Text(String(format: "512 x 512 cells   %ld GPU steps per frame   F %.4f   k %.4f", renderer.stepsPerFrame, feed, kill))
                        .font(.mono(11)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.7)

                    HStack(spacing: 10) {
                        Button(running ? "pause" : "play") { running.toggle(); renderer.running = running }
                        Button("reset") { renderer.reset() }
                        Spacer()
                    }
                    .buttonStyle(LabButton())

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.0) { preset in
                            Button(preset.0) { feed = preset.1; kill = preset.2 }
                        }
                    }
                    .buttonStyle(LabButton())

                    slider("feed F", value: $feed, range: 0.01...0.09)
                    slider("kill k", value: $kill, range: 0.045...0.07)
                } else {
                    Text("This device has no Metal GPU available.").foregroundStyle(Color.muted)
                }

                Notes(entry: entry)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color.ground)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: feed) { _, v in renderer?.feed = Float(v) }
        .onChange(of: kill) { _, v in renderer?.kill = Float(v) }
    }

    func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.4f", value.wrappedValue)).foregroundStyle(Color.ink)
            }
            .font(.mono(12)).foregroundStyle(Color.muted)
            Slider(value: value, in: range, step: 0.0005)
        }
    }
}
