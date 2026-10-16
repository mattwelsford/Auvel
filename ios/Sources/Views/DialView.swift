import SwiftUI

/// Direction B dial (design system §3.1, §6, R10).
/// Ring: volume, by circular drag or a straight vertical drag anywhere on the dial. One VoiceOver adjustable element.
/// Centre disc: play/pause, a separate button.
struct DialView: View {
    let volume: Double
    let muted: Bool
    let volumeEnabled: Bool
    let playEnabled: Bool
    let diameter: CGFloat
    let step: Double
    let onVolume: (Double) -> Void
    let onPlayPause: () -> Void

    @State private var dragStart: (volume: Double, angle: Double?)?
    @State private var lastStepIndex: Int?

    private var ringWidth: CGFloat { diameter * 22 / 330 }
    private var discDiameter: CGFloat { diameter * 208 / 330 }
    private var knobDiameter: CGFloat { diameter * 34 / 330 }

    var body: some View {
        ZStack {
            ring
                .accessibilityElement()
                .accessibilityLabel("Volume")
                .accessibilityValue(accessibilityValue)
                .accessibilityHint(volumeEnabled ? "Swipe up or down to change by \(Int(step * 100)) percent." : "")
                .accessibilityAdjustableAction { direction in
                    guard volumeEnabled else { return }
                    switch direction {
                    case .increment: change(to: volume + step)
                    case .decrement: change(to: volume - step)
                    @unknown default: break
                    }
                }

            disc
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .simultaneousGesture(volumeDrag)
    }

    // MARK: Ring

    private var ring: some View {
        let radius = (diameter - ringWidth) / 2
        return ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: ringWidth)
            Circle()
                .trim(from: 0, to: volume)
                .stroke(muted ? Color(.tertiaryLabel) : Color.gold,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.14), lineWidth: 1))
                .frame(width: knobDiameter, height: knobDiameter)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .offset(y: -radius)
                .rotationEffect(.degrees(volume * 360))
        }
        .padding(ringWidth / 2)
        .opacity(volumeEnabled ? 1 : 0.3)
    }

    // MARK: Disc

    /// A tap target rather than a Button, so a vertical drag that starts here never also toggles playback.
    private var disc: some View {
        Image(systemName: "playpause.fill")
            .font(.system(size: discDiameter * 0.27, weight: .semibold))
            .foregroundStyle(Color(.label))
            .frame(width: discDiameter, height: discDiameter)
            .background {
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.10), radius: 15, y: 10)
                    .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
            }
            .contentShape(Circle())
            .onTapGesture { if playEnabled { onPlayPause() } }
            .opacity(playEnabled ? 1 : 0.3)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Play or pause")
            .accessibilityHint(playEnabled ? "" : "Allow media keys on your Mac first.")
            .accessibilityAction { if playEnabled { onPlayPause() } }
    }

    // MARK: Gestures

    /// Starting on the ring: follow the finger around the circle. Starting on the disc: vertical drag,
    /// one dial height equals the full range. A tap on the disc stays a tap because of the 12 pt threshold.
    private var volumeDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard volumeEnabled else { return }
                let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                if dragStart == nil {
                    let distance = hypot(value.startLocation.x - centre.x, value.startLocation.y - centre.y)
                    let onRing = distance > discDiameter / 2
                    dragStart = (volume, onRing ? angle(of: value.startLocation, centre: centre) : nil)
                }
                guard let start = dragStart else { return }
                if start.angle != nil {
                    let current = angle(of: value.location, centre: centre)
                    // Avoid jumping between 0% and 100% across the top of the ring.
                    if abs(current - volume) > 0.5 {
                        change(to: volume > 0.5 ? 1 : 0)
                    } else {
                        change(to: current)
                    }
                } else {
                    change(to: start.volume - Double(value.translation.height / diameter))
                }
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    /// Angle of a point, 0 at the top, increasing clockwise, as a fraction of a turn.
    private func angle(of point: CGPoint, centre: CGPoint) -> Double {
        let radians = atan2(Double(point.x - centre.x), Double(centre.y - point.y))
        let turn = radians / (2 * .pi)
        return turn < 0 ? turn + 1 : turn
    }

    private func change(to level: Double) {
        let clamped = min(max(level, 0), 1)
        let index = Int((clamped / 0.05).rounded())
        if index != lastStepIndex {
            if clamped == 0 || clamped == 1 { Haptics.volumeLimit() } else if lastStepIndex != nil { Haptics.volumeStep() }
            lastStepIndex = index
        }
        onVolume(clamped)
    }

    private var accessibilityValue: String {
        if !volumeEnabled { return "Not adjustable" }
        if muted { return "Muted" }
        return "\(Int((volume * 100).rounded())) percent"
    }
}

/// Press feedback from design system §5.3. Reduce Motion: no scaling.
struct PressScaleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
