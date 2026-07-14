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
    // Spring (not bezier) so an interrupted appear reverses with velocity.
    // delay 0.06s = waits until shape is already mid-expansion
    // Without this delay the content "fights" the shape — looks amateur
    static let contentIn = Animation.spring(response: 0.32, dampingFraction: 0.85).delay(0.06)

    // CONTENT FADE-OUT: content disappears before the shape
    // Must finish BEFORE the shape starts collapsing
    static let contentOut = Animation.spring(response: 0.16, dampingFraction: 1.0)

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

    // NOTIFICATION CONTENT FADE-IN: springs in just after the pill starts
    // widening (the sequence in NotchController supplies the delay)
    static let notificationContentIn = Animation.spring(response: 0.28, dampingFraction: 0.8)

    // NOTIFICATION CONTENT FADE-OUT: fast critically-damped spring —
    // disappears decisively, no bounce, blends if interrupted
    static let notificationContentOut = Animation.spring(response: 0.14, dampingFraction: 1.0)

    // NOTIFICATION CONTRACT: fast, decisive, no bounce
    static let notificationContract = Animation.spring(response: 0.30, dampingFraction: 0.82)

    // MARK: - To-do hugging panel (PRD §8)

    // CONTENT HUG: the hero spring — panel height, row enter/exit, and the
    // Completed section all share this ONE spring so container and content
    // visibly move together instead of racing each other (§8.3). Slightly
    // underdamped on purpose: the panel should feel alive, not utilitarian.
    static let contentHug = Animation.spring(response: 0.45, dampingFraction: 0.60)

    // HINT FADE: contextual shortcut hints and ⌘-held badges (§7.1/7.2).
    // Deliberately a different weight of motion from contentHug — quick and
    // light, never competing with the height/row animation (§8.4).
    static let hintFade = Animation.spring(response: 0.18, dampingFraction: 1.0)
}
