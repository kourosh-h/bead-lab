#include <metal_stdlib>
using namespace metal;

// Must match GrayScottParams in GrayScottView.swift
struct Params {
    float feed;
    float kill;
    float2 touch;   // in grid cells
    float radius;   // 0 means no touch this frame
    int pad;
};

// One reaction-diffusion step. Each GPU thread updates one grid cell.
// u is stored in .x, v in .y. Periodic boundaries.
kernel void grayScottStep(texture2d<float, access::read> src [[texture(0)]],
                          texture2d<float, access::write> dst [[texture(1)]],
                          constant Params &p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    uint w = src.get_width(), h = src.get_height();
    if (gid.x >= w || gid.y >= h) return;

    float2 c = src.read(gid).xy;
    float2 lap = src.read(uint2((gid.x + 1) % w, gid.y)).xy
               + src.read(uint2((gid.x + w - 1) % w, gid.y)).xy
               + src.read(uint2(gid.x, (gid.y + 1) % h)).xy
               + src.read(uint2(gid.x, (gid.y + h - 1) % h)).xy
               - 4.0 * c;

    float u = c.x, v = c.y;
    float uvv = u * v * v;
    u += 0.2097 * lap.x - uvv + p.feed * (1.0 - u);
    v += 0.105 * lap.y + uvv - (p.feed + p.kill) * v;

    if (p.radius > 0 && distance(float2(gid), p.touch) < p.radius) {
        u = 0.5;
        v = 0.25;
    }
    dst.write(float4(u, v, 0, 1), gid);
}

// Colour the grid into the screen texture: dark ground, cobalt edges, ochre where v is high.
kernel void grayScottShow(texture2d<float, access::read> state [[texture(0)]],
                          texture2d<float, access::write> screen [[texture(1)]],
                          uint2 gid [[thread_position_in_grid]])
{
    uint sw = screen.get_width(), sh = screen.get_height();
    if (gid.x >= sw || gid.y >= sh) return;
    uint2 cell = uint2(gid.x * state.get_width() / sw, gid.y * state.get_height() / sh);
    float v = state.read(cell).y;

    float3 ground = float3(0.078, 0.090, 0.106);
    float3 cobalt = float3(0.498, 0.612, 1.000);
    float3 ochre  = float3(0.937, 0.643, 0.345);
    float t = clamp(v * 3.0, 0.0, 1.0);
    float3 col = t < 0.5 ? mix(ground, cobalt, t * 2.0) : mix(cobalt, ochre, t * 2.0 - 1.0);
    screen.write(float4(col, 1.0), gid);
}
