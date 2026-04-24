import SwiftUI

// MARK: - NotchAnimation — Centralized spring parameters
//
// All animation values in one place for consistent tuning.
// Springs preserve velocity when interrupted — beziers don't.

enum NotchAnimation {

    // EXPAND: notch opens downward
    // response 0.35 = ~300ms perceived, not too fast
    // dampingFraction 0.75 = small organic overshoot, then settles
    static let expand = Animation.spring(response: 0.35, dampingFraction: 0.75)

    // COLLAPSE: notch closes back up
    // Faster than expand (lower response) — like closing a drawer
    // More damped (higher dampingFraction) — decisive close, no bounce
    static let collapse = Animation.spring(response: 0.25, dampingFraction: 0.88)

    // HOVER: micro-expand on cursor
    // Very fast, almost no bounce — must feel reactive, not animated
    static let hover = Animation.spring(response: 0.20, dampingFraction: 0.90)

    // CONTENT FADE-IN: content appears inside the notch
    // delay 0.08s = waits until shape is already mid-expansion
    // Without this delay the content "fights" the shape — looks amateur
    static let contentIn = Animation.easeOut(duration: 0.18).delay(0.08)

    // CONTENT FADE-OUT: content disappears before the shape
    // Must finish BEFORE the shape starts collapsing
    static let contentOut = Animation.easeIn(duration: 0.08)

    // CARD STAGGER: each thumbnail enters with increasing delay
    static func cardEntry(index: Int) -> Animation {
        .spring(response: 0.38, dampingFraction: 0.62)
        .delay(Double(index) * 0.045)  // 0ms, 45ms, 90ms, 135ms...
    }

    // HOVER ON THUMBNAIL: light scale
    static let thumbnailHover = Animation.spring(response: 0.22, dampingFraction: 0.72)

    // NEW SCREENSHOT INSERTED: slide from right
    static let newScreenshot = Animation.spring(response: 0.42, dampingFraction: 0.65)

    // SCREENSHOT BOUNCE: notch pulses when screenshot arrives
    static let bounce = Animation.spring(response: 0.18, dampingFraction: 0.5)

    // MARK: - Capture Notification (Dynamic Island style)

    // NOTIFICATION EXPAND: pill widens horizontally — visible overshoot
    static let notificationExpand = Animation.spring(response: 0.45, dampingFraction: 0.6)

    // NOTIFICATION THUMBNAIL: smooth slide-in (no bounce/scale)
    static let notificationThumbnail = Animation.spring(response: 0.32, dampingFraction: 0.72)

    // NOTIFICATION CONTENT FADE-IN: appears 80ms after shape starts expanding
    static let notificationContentIn = Animation.easeOut(duration: 0.16).delay(0.08)

    // NOTIFICATION CONTENT FADE-OUT: fast disappear before contraction
    static let notificationContentOut = Animation.easeIn(duration: 0.10)

    // NOTIFICATION CONTRACT: fast, decisive, no bounce
    static let notificationContract = Animation.spring(response: 0.30, dampingFraction: 0.82)
}
