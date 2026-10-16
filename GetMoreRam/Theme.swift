//
//  Theme.swift
//  ram 6itoon
//
//  Visual language adapted from "SideInstaller by FrizzleM"
//  (https://github.com/FrizzleM/SideInstaller). Changes: trimmed to what this
//  app needs (no per-tab backdrop animation, popups or beta badge) and added
//  `IconBadge`, `LinkRow` and `SecondaryButtonStyle`.
//

import SwiftUI

// MARK: - Palette

enum Theme {
    /// Primary brand colour, a deep blue.
    static let accent = Color(red: 0.13, green: 0.44, blue: 0.96)
    /// Secondary brand colour, the far end of the gradient.
    static let accent2 = Color(red: 0.30, green: 0.68, blue: 1.0)
    /// Deep-navy halo behind the header icon.
    static let glow = Color(red: 1 / 255, green: 26 / 255, blue: 92 / 255)

    /// The signature diagonal gradient used for the logo, CTA and accents.
    static var brand: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Background

/// OLED black under a slow, low-opacity blue mesh gradient whose control
/// points sway on sine waves.
struct AppBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Color.black
                mesh(at: t)
                    .blur(radius: 24)
                    .opacity(0.2)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func mesh(at t: TimeInterval) -> some View {
        let points = meshPoints(at: t)
        if #available(iOS 18.0, *) {
            MeshGradient(width: 3, height: 3, points: points, colors: meshColors)
        } else {
            let centre = points[4]
            RadialGradient(colors: [Theme.accent2, Theme.accent, Theme.glow],
                           center: UnitPoint(x: CGFloat(centre.x), y: CGFloat(centre.y)),
                           startRadius: 0, endRadius: 600)
        }
    }

    private var meshColors: [Color] {
        [
            Theme.glow,    Theme.accent,   Theme.glow,
            Theme.accent2, Theme.accent,   Theme.accent2,
            Theme.glow,    Theme.accent2,  Theme.glow,
        ]
    }

    private func meshPoints(at t: TimeInterval) -> [SIMD2<Float>] {
        func osc(_ base: Double, _ amp: Double, _ speed: Double, _ phase: Double) -> Float {
            Float(base + amp * sin(t * speed + phase))
        }
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(osc(0.5, 0.18, 0.625, 0.0), 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, osc(0.5, 0.18, 0.55, 1.0)),
            SIMD2<Float>(osc(0.5, 0.12, 0.75, 2.0), osc(0.5, 0.12, 0.675, 3.0)),
            SIMD2<Float>(1, osc(0.5, 0.18, 0.60, 4.0)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(osc(0.5, 0.18, 0.65, 5.0), 1),
            SIMD2<Float>(1, 1),
        ]
    }
}

// MARK: - Cards

/// The neutral container every section sits in.
struct PanelCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardSurface(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// A pane of glass: the backdrop shows through, and the pane is drawn by its
/// rim, lit along the top, dim down the sides.
private struct CardSurface<S: InsettableShape>: ViewModifier {
    var shape: S

    func body(content: Content) -> some View {
        content
            .background(shape.fill(wash))
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
    }

    private var wash: LinearGradient {
        LinearGradient(colors: [.white.opacity(0.025), .clear],
                       startPoint: .top, endPoint: .bottom)
    }

    private var rim: LinearGradient {
        LinearGradient(stops: [.init(color: .white.opacity(0.38), location: 0),
                               .init(color: .white.opacity(0.08), location: 0.35),
                               .init(color: .white.opacity(0.05), location: 0.8),
                               .init(color: .white.opacity(0.18), location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Puts a card's surface behind this view, cut to `shape`.
    func cardSurface(in shape: some InsettableShape) -> some View {
        modifier(CardSurface(shape: shape))
    }
}

/// A `PanelCard` washed in a tint, for guidance, errors and success.
struct CalloutCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

// MARK: - Small components

/// Section title with a gradient glyph, used at the top of each card.
struct SectionTitle: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}

/// A compact, colour-coded status capsule.
struct StatusPill: View {
    var text: String
    var systemImage: String
    var color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

/// A tinted rounded-square glyph for rows.
struct IconBadge: View {
    var systemImage: String
    var tint: Color = Theme.accent2

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
    }
}

/// A row that opens a URL: tinted icon, title, optional detail, arrow.
struct LinkRow: View {
    var systemImage: String
    var tint: Color = Theme.accent2
    var title: String
    var detail: String? = nil
    var url: String

    var body: some View {
        Link(destination: URL(string: url) ?? URL(string: "https://github.com")!) {
            HStack(spacing: 12) {
                IconBadge(systemImage: systemImage, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
    }
}

/// The hero at the top of each screen: a glyph, the title, and an accessory.
struct BrandHeader<Accessory: View>: View {
    var icon: String
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(Theme.brand)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 86, height: 86)
            .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)

            VStack(spacing: 4) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            accessory()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - Field styling

private struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.07))
            )
    }
}

extension View {
    /// Wrap a plain text/secure field in the app's inset field background.
    func fieldBackground() -> some View { modifier(FieldBackground()) }
}

// MARK: - Buttons

/// The full-width gradient call-to-action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.brand)
            )
            .shadow(color: Theme.accent.opacity(0.4), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.45)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

/// A full-width quiet button on a tinted fill, for secondary and destructive
/// actions.
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent2
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

// MARK: - Page entrance

/// One object's part in a page's entrance cascade, staggered by `index`.
private struct CascadeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    private var delay: Double { Double(index) * 0.055 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.98, anchor: .top)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.smooth(duration: 0.4, extraBounce: 0.1).delay(delay)) {
                    shown = true
                }
            }
            .onDisappear { shown = false }
    }
}

extension View {
    /// Give an object its place in the entrance cascade (0 appears first).
    func cascadeItem(_ index: Int) -> some View { modifier(CascadeItem(index: index)) }
}
