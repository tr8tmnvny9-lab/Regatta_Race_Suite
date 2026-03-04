// DesignTokens.swift
// Regatta Tracker — Shared Design System
//
// All colours, typography helpers, reusable modifiers, and the AnimatedWaveBackground
// live here so every screen inherits the same maritime naval aesthetic.

import SwiftUI

// ─── Colour Tokens ────────────────────────────────────────────────────────────

extension Color {
    static let oceanDeep    = Color(red: 0.00, green: 0.05, blue: 0.15)
    static let oceanMid     = Color(red: 0.00, green: 0.15, blue: 0.35)
    static let oceanSurface = Color(red: 0.10, green: 0.40, blue: 0.70)
    static let cyanAccent   = Color(red: 0.00, green: 0.90, blue: 1.00)
    static let glassSurface = Color.white.opacity(0.08)
    static let glassBorder  = Color.white.opacity(0.18)
    static let statusRacing = Color(red: 0.13, green: 0.77, blue: 0.37)   // #22c55e
    static let statusWarn   = Color(red: 0.96, green: 0.62, blue: 0.04)   // #f59e0b
    static let statusError  = Color(red: 0.94, green: 0.27, blue: 0.27)   // #EF4444
}

// ─── Font Helpers ─────────────────────────────────────────────────────────────

struct RegattaFont {
    // Large data readout – monospaced digits, ultra-black
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }
    // Hero headings – rounded, black
    static func heroRounded(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    // Body text – rounded, semibold
    static func bodyRounded(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    // All-caps instrument labels – tight letter spacing
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy)
    }
    // Caption / meta text – monospaced
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    
    // Technical data readout
    static func data(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// ─── Wave Shape ───────────────────────────────────────────────────────────────

struct WaveShape: Shape {
    var offset: Angle
    var percent: Double

    var animatableData: Double {
        get { offset.degrees }
        set { offset = Angle(degrees: newValue) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }
        
        let waveHeight: CGFloat = 20
        let yOffset = CGFloat(1 - percent) * (rect.height - waveHeight)
        let start = offset
        let end = start + Angle(degrees: 360)

        path.move(to: CGPoint(x: 0, y: yOffset + waveHeight * CGFloat(sin(start.radians))))
        for x in stride(from: 0, to: rect.width + 5, by: 5) {
            let rel = x / rect.width
            let angle = start.radians + (end.radians - start.radians) * Double(rel)
            let y = yOffset + waveHeight * CGFloat(sin(angle))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// ─── Animated Wave Background ─────────────────────────────────────────────────
// Shared across Login, Welcome, Configure, and Main HUD so transitions feel seamless.

struct AnimatedWaveBackground: View {
    @State private var wave1 = Angle(degrees: 0)
    @State private var wave2 = Angle(degrees: 0)
    @State private var glowOffset = CGSize.zero

    var body: some View {
        ZStack {
            // Deep ocean gradient
            LinearGradient(
                gradient: Gradient(colors: [.oceanDeep, .oceanMid, .oceanSurface]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Breathing glow orbs
            Circle()
                .fill(Color.cyanAccent.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: glowOffset.width - 200, y: glowOffset.height - 200)
            Circle()
                .fill(Color.blue.opacity(0.09))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -glowOffset.width + 200, y: -glowOffset.height + 160)
            
            // Distant waves — very slow & faint
            WaveShape(offset: wave2, percent: 0.30)
                .fill(Color.white.opacity(0.025))
                .ignoresSafeArea()
            WaveShape(offset: wave2 + Angle(degrees: 120), percent: 0.28)
                .fill(Color.cyanAccent.opacity(0.035))
                .ignoresSafeArea()
                .offset(y: 30)

            // Mid waves
            WaveShape(offset: wave1, percent: 0.35)
                .fill(Color.white.opacity(0.07))
                .ignoresSafeArea()
                .offset(y: 60)
            WaveShape(offset: wave1 + Angle(degrees: 180), percent: 0.32)
                .fill(Color.cyanAccent.opacity(0.10))
                .ignoresSafeArea()
                .offset(y: 80)

            // Foreground wave — fastest
            WaveShape(offset: wave1 * 1.5 + Angle(degrees: 90), percent: 0.40)
                .fill(Color.white.opacity(0.04))
                .ignoresSafeArea()
                .offset(y: 110)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped() // Prevent decorative circles from expanding the parent's width
        .ignoresSafeArea(.all)
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { wave1 = .init(degrees: 360) }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { wave2 = .init(degrees: 360) }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                glowOffset = CGSize(width: 110, height: 110)
            }
        }
    }
}

// ─── True Liquid Glass Modifier ───────────────────────────────────────────────
// This creates the "Apple" look: multi-layered glass with specular highlights,
// inner bevels, and a refractive-looking border.

struct TrueLiquidGlass: ViewModifier {
    var cornerRadius: CGFloat = 24
    var fillOpacity: Double = 0.08
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // 1. The base blur material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // 2. Interior "tint" to give it body
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(fillOpacity))
                    
                    // 3. Inner Bevel / Reflection (Bottom Edge)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            }
            // 4. Specular Highlight (The "Light Catch" on top/left)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.2),
                                .init(color: .clear, location: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // 5. Outer Refractive Border (Subtle blue/cyan tint at edges)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            colors: [.glassBorder, .cyanAccent.opacity(0.1), .glassBorder, .glassBorder],
                            center: .center,
                            angle: .degrees(135)
                        ),
                        lineWidth: 0.5
                    )
            )
            // 6. Deep drop shadow for 3D POP
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func trueLiquidGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(TrueLiquidGlass(cornerRadius: cornerRadius))
    }
    
    // Legacy support or quick variant
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(TrueLiquidGlass(cornerRadius: cornerRadius))
    }
}

// ─── Liquid Glass Button Style ────────────────────────────────────────────────
// "3-D pressing in" feel: depresses on press, spring return

struct LiquidGlassButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .font(RegattaFont.heroRounded(16))
            .foregroundColor(isPrimary ? .black : .white)
            .background {
                if isPrimary {
                    ZStack {
                        // The base "glass body" with high-density white
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.85))
                        
                        // Refractive edge light
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                        
                        // Surface sheen
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .shadow(color: .white.opacity(0.3), radius: 15, x: 0, y: 0)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.glassSurface)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.glassBorder, lineWidth: 1))
                        // Top-highlight for 3-D glass effect
                        .overlay(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.05 : 0.20),
                radius: configuration.isPressed ? 4 : 12,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Secondary (glass) variant helper
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ─── Animated Pulse Dot ───────────────────────────────────────────────────────

struct AnimatedPulseDot: View {
    let color: Color
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 1.6 : 1.0)
                .opacity(pulsing ? 0 : 0.5)
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.9), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// ─── Compass Rose / Heading Arrow ─────────────────────────────────────────────
// Small decorative compass arrow used on the heading card.

struct CompassArrow: View {
    let degrees: Double
    var body: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.cyanAccent)
            .rotationEffect(.degrees(degrees))
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: degrees)
    }
}

// ─── Shimmer Effect ───────────────────────────────────────────────────────────
// Used on the boat identity card while awaiting assignment from backend.

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.3),
                                    .init(color: .white.opacity(0.35), location: 0.5),
                                    .init(color: .clear, location: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(x: 2)
                        .offset(x: phase * geo.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
