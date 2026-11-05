import SwiftUI

// Colours from the website: near-black ground, cobalt and ochre beads.
extension Color {
    static let ground = Color(red: 0.047, green: 0.055, blue: 0.063)   // #0c0e10
    static let paper  = Color(red: 0.078, green: 0.090, blue: 0.106)   // #14171b
    static let ink    = Color(red: 0.902, green: 0.914, blue: 0.925)   // #e6e9ec
    static let muted  = Color(red: 0.584, green: 0.620, blue: 0.659)   // #959ea8
    static let rule   = Color(red: 0.169, green: 0.192, blue: 0.220)   // #2b3138
    static let cobalt = Color(red: 0.498, green: 0.612, blue: 1.000)   // #7f9cff
    static let ochre  = Color(red: 0.937, green: 0.643, blue: 0.345)   // #efa458
}

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
}
