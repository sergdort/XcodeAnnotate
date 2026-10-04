import AppKit
import SwiftUI

/// Colors from the Paper design, each with a light and a dark value.
enum Palette {
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x26272B)
    static let well = dynamic(light: 0xF5F6F8, dark: 0x1E1F22)
    static let ink = dynamic(light: 0x1D1D1F, dark: 0xF2F2F4)
    static let secondary = dynamic(light: 0x6E6E73, dark: 0x9A9AA0)
    static let lineNumber = dynamic(light: 0xA1A1A6, dark: 0x6E6E73)
    static let accent = dynamic(light: 0x0A6CFF, dark: 0x2F86FF)
    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 0, alpha: 0.08)
    })

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.isDark ? dark : light)
        })
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// A keyboard hint such as `esc` or `↩`, optionally filled with the accent color.
struct KeyCap: View {
    let label: String
    var prominent = false

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(prominent ? Color.white : Palette.secondary)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 18)
            .background(prominent ? Palette.accent : Palette.well, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(prominent ? .clear : Palette.hairline))
    }
}

/// A footer action: a title followed by its key, like `Copy ↩`.
struct KeyButton: View {
    let title: String
    let key: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: prominent ? .semibold : .regular))
                    .foregroundStyle(prominent ? Palette.ink : Palette.secondary)
                KeyCap(label: key, prominent: prominent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The rounded white card every floating surface sits on.
struct PanelCard<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: width)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Room for the window shadow drawn by AppKit around the transparent panel.
            .padding(1)
    }
}
