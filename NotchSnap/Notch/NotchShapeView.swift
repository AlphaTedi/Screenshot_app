import SwiftUI

// MARK: - NotchState

enum NotchState: Equatable {
    case idle
    case hovering
    case expanded
    case captureNotification  // micro-expand: thumbnail + checkmark, auto-dismiss
}

// MARK: - NotchShape — Custom shape replicating Alcove's notch

struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var filletRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, filletRadius) }
        set {
            bottomRadius = newValue.first
            filletRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let fr = min(max(filletRadius, 0), w / 4, h / 3)
        let bodyLeft = fr
        let bodyRight = w - fr
        let cr = min(max(bottomRadius, 0), h / 3, (bodyRight - bodyLeft) / 3)

        if fr > 0.5 {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.addQuadCurve(to: CGPoint(x: bodyRight, y: fr), control: CGPoint(x: bodyRight, y: 0))
            path.addLine(to: CGPoint(x: bodyRight, y: h - cr))
            if cr > 0.5 {
                path.addCurve(to: CGPoint(x: bodyRight - cr, y: h),
                              control1: CGPoint(x: bodyRight, y: h - cr * 0.44),
                              control2: CGPoint(x: bodyRight - cr * 0.44, y: h))
            } else {
                path.addLine(to: CGPoint(x: bodyRight, y: h))
            }
            let bottomLeftX = cr > 0.5 ? bodyLeft + cr : bodyLeft
            path.addLine(to: CGPoint(x: bottomLeftX, y: h))
            if cr > 0.5 {
                path.addCurve(to: CGPoint(x: bodyLeft, y: h - cr),
                              control1: CGPoint(x: bodyLeft + cr * 0.44, y: h),
                              control2: CGPoint(x: bodyLeft, y: h - cr * 0.44))
            }
            path.addLine(to: CGPoint(x: bodyLeft, y: fr))
            path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: bodyLeft, y: 0))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: h - cr))
            if cr > 0.5 {
                path.addCurve(to: CGPoint(x: w - cr, y: h),
                              control1: CGPoint(x: w, y: h - cr * 0.44),
                              control2: CGPoint(x: w - cr * 0.44, y: h))
            }
            path.addLine(to: CGPoint(x: cr, y: h))
            if cr > 0.5 {
                path.addCurve(to: CGPoint(x: 0, y: h - cr),
                              control1: CGPoint(x: cr * 0.44, y: h),
                              control2: CGPoint(x: 0, y: h - cr * 0.44))
            }
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Squish/Stretch values for KeyframeAnimator

struct NotchSquishValues {
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var verticalOffset: CGFloat = 0.0
}

// MARK: - NotchShapeView — Animated notch with Dynamic Island bounciness

struct NotchShapeView: View {
    @Binding var state: NotchState
    let notchSize: CGSize
    let expandedSize: CGSize
    let hasPhysicalNotch: Bool
    var screenshotJustArrived: Bool = false
    var contentVisible: Bool = false
    var notificationContentVisible: Bool = false
    var notificationWide: Bool = false
    let content: AnyView
    var notificationContent: AnyView? = nil

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("notchCornerRadius") private var userCornerRadius: Double = 10

    // MARK: - Raccordatura radius per state

    private var currentFilletRadius: CGFloat {
        switch state {
        case .idle:                 return 12
        case .hovering:             return 14
        case .expanded:             return 12
        case .captureNotification:  return 12
        }
    }

    // MARK: - Dimensions per state

    private var currentWidth: CGFloat {
        let base: CGFloat = {
            switch state {
            case .idle:                 return notchSize.width + currentFilletRadius * 2
            case .hovering:             return notchSize.width + 28 + currentFilletRadius * 2
            case .expanded:             return expandedSize.width
            case .captureNotification:  return notificationWide ? 320 : notchSize.width + 80 + currentFilletRadius * 2
            }
        }()
        return screenshotJustArrived ? base + 16 : base
    }

    private var currentHeight: CGFloat {
        let base: CGFloat = {
            switch state {
            case .idle:                 return notchSize.height
            case .hovering:             return notchSize.height + 6
            case .expanded:             return expandedSize.height
            case .captureNotification:  return notchSize.height
            }
        }()
        return screenshotJustArrived ? base + 12 : base
    }

    private var bottomCornerRadius: CGFloat {
        // Scale with height so taller presets (Wide / Extra Large) keep a
        // visibly rounded silhouette instead of looking like a flat slab.
        // Cap at 28pt so tiny notches don't get over-rounded.
        let base = CGFloat(userCornerRadius)
        let h = expandedSize.height
        let scaled = max(base, min(28, h * 0.13))
        switch state {
        case .idle:                 return base
        case .hovering:             return base + 2
        case .expanded:             return scaled + 4
        case .captureNotification:  return base
        }
    }

    // MARK: - Shadow

    private var shadowColor: Color {
        switch state {
        case .idle:                 return .clear
        case .hovering:             return .black.opacity(0.35)
        case .expanded:             return .clear
        case .captureNotification:  return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch state {
        case .idle:                 return 0
        case .hovering:             return 20
        case .expanded:             return 0
        case .captureNotification:  return 0
        }
    }

    // MARK: - Spring animation selection

    private var shapeAnimation: Animation {
        if reduceMotion { return .easeInOut(duration: 0.15) }
        if screenshotJustArrived { return NotchAnimation.bounce }
        switch state {
        case .expanded:             return NotchAnimation.expand
        case .hovering:             return NotchAnimation.hover
        case .idle:                 return NotchAnimation.collapse
        case .captureNotification:  return NotchAnimation.notificationExpand
        }
    }

    // MARK: - Squish state (Dynamic Island style)
    @State private var squishScaleX: CGFloat = 1.0
    @State private var squishScaleY: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // The notch shape with squish/stretch overlay
            NotchShape(
                bottomRadius: bottomCornerRadius,
                filletRadius: currentFilletRadius
            )
            .fill(Color.black)
            .frame(width: currentWidth, height: currentHeight)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
            .scaleEffect(x: squishScaleX, y: squishScaleY, anchor: .top)
            .animation(shapeAnimation, value: state)
            .animation(NotchAnimation.bounce, value: screenshotJustArrived)
            .onChange(of: state) { newState in
                if !reduceMotion {
                    runSquishAnimation(for: newState)
                }
            }

            // Content gallery — staggered fade-in.
            // The content is hard-clipped to the same NotchShape used for the
            // black silhouette so thumbnails / tiles can never paint outside
            // the rounded body (otherwise on taller presets the bottom rows
            // would visibly stick out past the rounded corners and look like
            // they had been "cut").
            if state == .expanded {
                content
                    .frame(width: expandedSize.width - 32, height: expandedSize.height - notchSize.height - 8)
                    .padding(.top, notchSize.height + 4)
                    .opacity(contentVisible ? 1.0 : 0.0)
                    .scaleEffect(contentVisible ? 1.0 : 0.96)
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.1) : NotchAnimation.contentIn,
                        value: contentVisible
                    )
                    .frame(width: currentWidth, height: currentHeight, alignment: .top)
                    .mask(
                        NotchShape(
                            bottomRadius: bottomCornerRadius,
                            filletRadius: currentFilletRadius
                        )
                        .frame(width: currentWidth, height: currentHeight)
                    )
            }

            // Notification content — icon in left wing, text in right wing
            // The physical notch (~notchSize.width) sits in the center of the 280pt pill,
            // so content must stay in the lateral wings to avoid the safe area.
            if state == .captureNotification, let notificationContent = notificationContent {
                let pillWidth: CGFloat = notificationWide ? 320 : notchSize.width + 80 + currentFilletRadius * 2
                let wingWidth = (pillWidth - notchSize.width) / 2 - currentFilletRadius
                notificationContent
                    .frame(width: pillWidth - currentFilletRadius * 2, height: notchSize.height - 4)
                    .padding(.top, 2)
                    .opacity(notificationContentVisible ? 1.0 : 0.0)
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.1) : NotchAnimation.notificationContentIn,
                        value: notificationContentVisible
                    )
                    .environment(\.notchWingWidth, wingWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Squish Animation (multi-phase spring sequence)

    private func runSquishAnimation(for newState: NotchState) {
        switch newState {
        case .expanded:
            // Phase 1: anticipation squish (80ms)
            withAnimation(.spring(duration: 0.08, bounce: 0.0)) {
                squishScaleX = 0.96
                squishScaleY = 1.04
            }
            // Phase 2: overshoot (180ms later)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(duration: 0.25, bounce: 0.3)) {
                    squishScaleX = 1.02
                    squishScaleY = 0.99
                }
            }
            // Phase 3: settle (350ms later)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                    squishScaleX = 1.0
                    squishScaleY = 1.0
                }
            }

        case .idle:
            // Phase 1: micro expand
            withAnimation(.spring(duration: 0.12, bounce: 0.2)) {
                squishScaleX = 1.02
                squishScaleY = 0.98
            }
            // Phase 2: settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(duration: 0.28, bounce: 0.0)) {
                    squishScaleX = 1.0
                    squishScaleY = 1.0
                }
            }

        case .hovering:
            // Micro breath
            withAnimation(.spring(duration: 0.22, bounce: 0.3)) {
                squishScaleX = 1.0
                squishScaleY = 1.0
            }

        case .captureNotification:
            // Horizontal stretch — pill widens
            withAnimation(.spring(duration: 0.12, bounce: 0.2)) {
                squishScaleX = 1.03
                squishScaleY = 0.97
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                    squishScaleX = 1.0
                    squishScaleY = 1.0
                }
            }
        }
    }
}
