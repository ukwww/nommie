import SwiftUI

// The one-time flourish shown right after onboarding: soft beige kitchen
// utensils rain down under "Setting the table…", then the screen splits down
// the middle like curtains to reveal the app.

// MARK: - Custom utensil shapes (line art)

struct PlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let box = CGRect(x: rect.midX - r, y: rect.midY - r, width: 2 * r, height: 2 * r)
        p.addEllipse(in: box.insetBy(dx: r * 0.06, dy: r * 0.06))
        p.addEllipse(in: box.insetBy(dx: r * 0.42, dy: r * 0.42))
        return p
    }
}

struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX + 0.12 * rect.width, y: rect.minY + 0.34 * rect.height,
                                width: 0.76 * rect.width, height: 0.15 * rect.height))
        p.move(to: pt(0.13, 0.41))
        p.addQuadCurve(to: pt(0.5, 0.88), control: pt(0.2, 0.86))
        p.addQuadCurve(to: pt(0.87, 0.41), control: pt(0.8, 0.86))
        return p
    }
}

struct SpoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX + 0.32 * rect.width, y: rect.minY + 0.05 * rect.height,
                                width: 0.36 * rect.width, height: 0.44 * rect.height))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + 0.48 * rect.height))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 0.95 * rect.height))
        return p
    }
}

struct KnifeShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        // Blade — a slim rounded triangle, tip at top
        p.move(to: pt(0.5, 0.05))
        p.addQuadCurve(to: pt(0.6, 0.52), control: pt(0.62, 0.3))
        p.addLine(to: pt(0.44, 0.52))
        p.addLine(to: pt(0.44, 0.1))
        p.addQuadCurve(to: pt(0.5, 0.05), control: pt(0.44, 0.06))
        p.closeSubpath()
        // Handle
        p.addRoundedRect(in: CGRect(x: rect.minX + 0.44 * rect.width, y: rect.minY + 0.54 * rect.height,
                                    width: 0.16 * rect.width, height: 0.4 * rect.height),
                         cornerSize: CGSize(width: rect.width * 0.05, height: rect.width * 0.05))
        return p
    }
}

struct WhiskShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.05))
        p.addLine(to: pt(0.5, 0.42))
        for ctrl in [CGFloat(0.15), 0.34, 0.66, 0.85] {
            p.move(to: pt(0.5, 0.42))
            p.addQuadCurve(to: pt(0.5, 0.93), control: pt(ctrl, 0.6))
        }
        return p
    }
}

enum Utensil: CaseIterable {
    case plate, bowl, spoon, knife, whisk

    @ViewBuilder
    func view(size: CGFloat, color: Color) -> some View {
        let lw = max(1.3, size * 0.045)
        switch self {
        case .plate: PlateShape().stroke(color, lineWidth: lw).frame(width: size, height: size)
        case .bowl:  BowlShape().stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)).frame(width: size, height: size)
        case .spoon: SpoonShape().stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round)).frame(width: size, height: size)
        case .knife: KnifeShape().stroke(color, style: StrokeStyle(lineWidth: lw, lineJoin: .round)).frame(width: size, height: size)
        case .whisk: WhiskShape().stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round)).frame(width: size, height: size)
        }
    }
}

// MARK: - Falling item

private struct FallingItem: Identifiable {
    let id = UUID()
    let utensil: Utensil
    let xFraction: CGFloat
    let size: CGFloat
    let baseRotation: Double
    let spin: Double
    let delay: Double
    let duration: Double

    static func generate() -> [FallingItem] {
        let all = Utensil.allCases
        return (0..<16).map { i in
            FallingItem(
                utensil: all[i % all.count],
                xFraction: CGFloat.random(in: 0.06...0.94),
                size: CGFloat.random(in: 26...46),
                baseRotation: Double.random(in: -30...30),
                spin: Double.random(in: -50...50),
                delay: Double.random(in: 0...1.4),
                duration: Double.random(in: 2.4...3.8)
            )
        }
    }
}

// MARK: - Reveal view

struct LaunchRevealView: View {
    let onFinished: () -> Void

    @State private var dropped = false
    @State private var contentOpacity: Double = 0
    @State private var split: CGFloat = 0

    private let items = FallingItem.generate()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Two curtain panels that slide apart to reveal the app behind.
                HStack(spacing: 0) {
                    Rectangle().fill(Color.nommieBackground)
                        .frame(width: w / 2 + 1)
                        .offset(x: -split * (w / 2 + 1))
                    Rectangle().fill(Color.nommieBackground)
                        .frame(width: w / 2 + 1)
                        .offset(x: split * (w / 2 + 1))
                }

                // Falling utensils + the line, fading out as the curtains open.
                ZStack {
                    ForEach(items) { item in
                        item.utensil.view(size: item.size, color: Color.nommieBrown.opacity(0.16))
                            .rotationEffect(.degrees(item.baseRotation + (dropped ? item.spin : 0)))
                            .position(x: w * item.xFraction, y: dropped ? h + 90 : -90)
                            .animation(
                                .linear(duration: item.duration)
                                    .delay(item.delay)
                                    .repeatForever(autoreverses: false),
                                value: dropped
                            )
                    }

                    Text("Setting the table…")
                        .font(Font.custom("Lora-Bold", size: 23))
                        .foregroundColor(.nommieGreen)
                        .opacity(contentOpacity)
                }
            }
            .onAppear {
                dropped = true
                withAnimation(.easeOut(duration: 0.5)) { contentOpacity = 1 }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                    withAnimation(.easeIn(duration: 0.25)) { contentOpacity = 0 }
                    withAnimation(.easeInOut(duration: 0.7)) { split = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onFinished() }
                }
            }
        }
        .ignoresSafeArea()
    }
}
