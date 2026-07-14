//
//  DesignSystem.swift
//  NotchSnap
//
//  Concrete design tokens and reusable SwiftUI components matching the
//  approved mockups in notchsnap_design_reference_prd.md.
//
//  PURPOSE: Fable 5 has been drifting from the approved look because prior
//  PRDs described styling in prose ("border radius 8px", "muted gray text").
//  This file gives literal, importable constants and components instead —
//  there is no separate "design system library," this Swift file IS the
//  design system for this app. Reference these types directly in every
//  screen rather than re-specifying colors/spacing/radii inline per view.
//

import SwiftUI

// MARK: - Design Tokens

enum DSColor {
    // Panel & structure
    static let panelBackground = Color(hex: "#111111")
    static let outerBackground = Color(hex: "#000000")
    static let panelBorder = Color(hex: "#333333")
    static let divider = Color(hex: "#2A2A2A")
    static let dividerSubtle = Color(hex: "#222222")

    // Text
    static let textPrimary = Color(hex: "#E5E5E5")
    static let textPrimaryBright = Color(hex: "#EEEEEE")
    static let textSecondary = Color(hex: "#888888")
    static let textMuted = Color(hex: "#777777")
    static let textFaint = Color(hex: "#666666")
    static let textHint = Color(hex: "#555555")

    // Interactive / focus
    static let focusAccent = Color(hex: "#4A9EFF")
    static let fieldBackground = Color(hex: "#1A1A1A")
    static let focusedRowBackground = Color(hex: "#1C1C1C")

    // Primary action (Create button etc.)
    static let primaryFill = Color(hex: "#EEEEEE")
    static let primaryText = Color(hex: "#111111")

    // Reference category palette (actual colors are user-assigned per
    // category at creation time — see CT-1 in notchsnap_todo_pivot_prd.md.
    // These are the values used across every mockup for consistency when
    // building preview/seed data.)
    enum CategoryPalette {
        static let blue = Color(hex: "#7FB8E0")     // "Work" in mockups
        static let purple = Color(hex: "#C99EE0")   // "Personal" in mockups
        static let amber = Color(hex: "#E8C15A")
        static let green = Color(hex: "#8FBF7A")
        static let coral = Color(hex: "#E07A5F")

        static let all: [Color] = [blue, purple, amber, green, coral]
    }

    // Urgency (see TodoUrgency in notchsnap_todo_pivot_prd.md Section 10)
    static let urgencyLow = Color(hex: "#8FBF7A")
    static let urgencyMedium = Color(hex: "#E8C15A")
    static let urgencyHigh = Color(hex: "#E07A5F")
}

enum DSSpacing {
    static let panelPadding: CGFloat = 16
    static let rowGap: CGFloat = 12
    static let rowInternalGap: CGFloat = 10
    static let tabRowBottomPadding: CGFloat = 12
    static let tabRowBottomMargin: CGFloat = 14
    static let checklistIndent: CGFloat = 24
}

enum DSRadius {
    static let panelCorner: CGFloat = 18
    static let controlCorner: CGFloat = 8
    static let chipCorner: CGFloat = 6
    static let checkboxCorner: CGFloat = 4
    static let checklistCheckboxCorner: CGFloat = 3
    static let hintChipCorner: CGFloat = 4
}

enum DSFont {
    static let todoTitle: Font = .system(size: 13)
    static let tabLabel: Font = .system(size: 11)
    static let sectionLabel: Font = .system(size: 10, weight: .regular)
    static let hint: Font = .system(size: 9)
    static let checklistItem: Font = .system(size: 11)
    static let buttonLabel: Font = .system(size: 12, weight: .medium)
}

enum DSAnimation {
    // The one primary spring used for height changes, row enter/exit,
    // Completed section expand/collapse, tab switches, and progress-ring
    // fill changes. See notchsnap_todo_pivot_prd.md Section 8.2.
    static let primary: Animation = .interpolatingSpring(mass: 1, stiffness: 170, damping: 20)
    // Rough SwiftUI equivalent of response: 0.45, dampingFraction: 0.60 —
    // tune numerically against a real build rather than trusting this
    // conversion blindly; the important part is reusing ONE spring
    // definition everywhere rather than ad hoc values per view.

    // Secondary, faster transitions: contextual hint fade, modifier-held
    // badge reveal. Never use the primary spring for these.
    static let secondary: Animation = .easeOut(duration: 0.18)
}

// MARK: - Color hex convenience

extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Reusable component: Category tab chip

/// A single tab in the browsing view's tab row. Only the ACTIVE tab is
/// rendered in its category color — inactive tabs are always neutral.
/// See TD-9 / TD-2 in notchsnap_todo_pivot_prd.md — this is not optional
/// styling, it's a functional requirement.
struct CategoryTabChip: View {
    let title: String
    let categoryColor: Color
    let isActive: Bool
    let progress: Double?           // 0...1, nil if category has zero to-dos
    let numberBadge: Int?           // shown only while a modifier key is held

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(DSFont.tabLabel)
                .foregroundColor(isActive ? DSColor.primaryText : DSColor.textSecondary)

            if let progress {
                ProgressRing(progress: progress, tint: isActive ? DSColor.primaryText : DSColor.textFaint)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(isActive ? categoryColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.chipCorner))
        .overlay(alignment: .topTrailing) {
            if let numberBadge {
                Text("\(numberBadge)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(isActive ? DSColor.primaryText : Color(hex: "#AAAAAA"))
                    .padding(.horizontal, 3)
                    .background(isActive ? DSColor.primaryFill : Color(hex: "#333333"))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: 6, y: -8)
                    .transition(.opacity)
            }
        }
        .animation(DSAnimation.secondary, value: numberBadge)
    }
}

/// The dedicated "+" creation tab — always present, no category color of
/// its own. See Section 6.1 of notchsnap_todo_pivot_prd.md.
struct CreationTabChip: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 12))
            .foregroundColor(isActive ? DSColor.primaryText : DSColor.textPrimaryBright)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isActive ? DSColor.primaryFill : Color(hex: "#333333"))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.chipCorner))
    }
}

// MARK: - Reusable component: Progress ring (Section 9.2)

struct ProgressRing: View {
    let progress: Double   // 0...1
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.3), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(DSAnimation.primary, value: progress)
    }
}

// MARK: - Reusable component: To-do row

struct TodoRow: View {
    let title: String
    let categoryColor: Color
    let isFocused: Bool
    let shortcutHint: String?   // only the focused row ever passes non-nil here

    var body: some View {
        HStack(spacing: DSSpacing.rowInternalGap) {
            RoundedRectangle(cornerRadius: DSRadius.checkboxCorner)
                .strokeBorder(categoryColor, lineWidth: 1.5)
                .frame(width: 14, height: 14)

            Text(title)
                .font(DSFont.todoTitle)
                .foregroundColor(DSColor.textPrimary)

            Spacer()

            if let shortcutHint {
                ShortcutHintBadge(text: shortcutHint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isFocused ? DSColor.focusedRowBackground : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.controlCorner)
                .stroke(isFocused ? DSColor.focusAccent : Color.clear, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.controlCorner))
    }
}

// MARK: - Reusable component: Shortcut hint badge

struct ShortcutHintBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DSFont.hint)
            .foregroundColor(DSColor.textHint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.hintChipCorner)
                    .stroke(DSColor.panelBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Reusable component: Combo box row (creation flow)

/// Used for BOTH category and urgency selection in the creation flow.
/// Category swatch is a rounded square; urgency swatch is a circle —
/// this shape difference is intentional, see Section 3.2 of
/// notchsnap_design_reference_prd.md. Do not standardize the two to one shape.
struct ComboBoxRow: View {
    enum SwatchShape { case roundedSquare, circle }

    let label: String
    let swatchColor: Color
    let swatchShape: SwatchShape
    let cycleShortcutHint: String
    /// Urgency/entity PRD §1.4: the creation flow's urgency swatch is 11px —
    /// the one place urgency is the row's primary subject.
    var swatchDiameter: CGFloat = 10

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                swatch
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(DSColor.textPrimaryBright)
            }
            Spacer()
            ShortcutHintBadge(text: cycleShortcutHint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(DSColor.fieldBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.controlCorner)
                .stroke(DSColor.panelBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.controlCorner))
    }

    @ViewBuilder
    private var swatch: some View {
        switch swatchShape {
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 3)
                .fill(swatchColor)
                .frame(width: swatchDiameter, height: swatchDiameter)
        case .circle:
            Circle()
                .fill(swatchColor)
                .frame(width: swatchDiameter, height: swatchDiameter)
        }
    }
}

// MARK: - Reusable component: Primary action button (Create, etc.)

struct PrimaryActionButton: View {
    let title: String
    let shortcutHint: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(DSFont.buttonLabel)
                .foregroundColor(DSColor.primaryText)
            Text(shortcutHint)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#333333"))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color(hex: "#CCCCCC"))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.hintChipCorner))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(DSColor.primaryFill)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.controlCorner))
    }
}

// MARK: - Reusable component: Category color-picker swatch (Section 4 form)

struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.white : DSColor.panelBorder, lineWidth: isSelected ? 2 : 1.5)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DSColor.primaryText)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            // Selection is NEVER implied by position alone — always pair
            // the border + checkmark, per CT-6 in notchsnap_todo_pivot_prd.md.
    }
}

// MARK: - Addendum: urgency clarity & inline entity highlighting
// (notchsnap_urgency_entity_prd.md §3 — supplied by Marcello 2026-07-14.
// Adapted in two flagged ways: labels route through L10n/TodoUrgency.fullLabel
// because the app ships EN+IT tables, and the native .help() tooltip was
// replaced by UrgencyTooltip per Marcello's answer to the §4 open question —
// hover AND keyboard focus, immediate, no system delay.)

// MARK: Urgency dot (§1)

enum DSUrgencyDot {
    static let diameter: CGFloat = 9
    static let creationFlowSwatchDiameter: CGFloat = 11
}

struct UrgencyDot: View {
    let urgency: TodoUrgency

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: DSUrgencyDot.diameter, height: DSUrgencyDot.diameter)
    }

    private var color: Color {
        switch urgency {
        case .low: return DSColor.urgencyLow.opacity(0.5) // UG-5: rows skip Low entirely
        case .medium: return DSColor.urgencyMedium
        case .high: return DSColor.urgencyHigh
        }
    }
}

/// §1.4 tooltip: dark bubble with a pointer, shown immediately on row
/// hover/keyboard focus near the dot — never by default (UG-2/UG-3).
struct UrgencyTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(DSColor.textPrimaryBright)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DSColor.divider)   // #2A2A2A per mockup
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#444444"), lineWidth: 0.5)
            )
            .overlay(alignment: .bottom) {
                // Pointer: the rotated-square trick from the mockup.
                Rectangle()
                    .fill(DSColor.divider)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
                    .offset(y: 3.5)
            }
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .fixedSize()
    }
}

// MARK: Inline entity chips (§2)

enum EntityKind {
    case link, date, mention, code
}

enum DSEntityChip {
    static func background(for kind: EntityKind) -> Color {
        switch kind {
        case .link: return Color(hex: "#1A2733")
        case .date: return Color(hex: "#231F14")
        case .mention: return Color(hex: "#2A1F33")
        case .code: return Color(hex: "#1C1C1C")
        }
    }

    static func border(for kind: EntityKind) -> Color {
        switch kind {
        case .link: return Color(hex: "#2F4A5C")
        case .date: return Color(hex: "#4A3F22")
        case .mention: return Color(hex: "#493459")
        case .code: return Color(hex: "#3A3A3A")
        }
    }

    static func text(for kind: EntityKind) -> Color {
        switch kind {
        case .link: return DSColor.CategoryPalette.blue
        case .date: return DSColor.CategoryPalette.amber
        case .mention: return DSColor.CategoryPalette.purple
        case .code: return Color(hex: "#BBBBBB")
        }
    }

    static func sfSymbol(for kind: EntityKind) -> String? {
        switch kind {
        case .link: return "link"
        case .date: return "calendar"
        case .mention: return "at"
        case .code: return nil // monospace font is the signal, no icon
        }
    }
}

// NOTE: this SwiftUI view is a visual reference for a SINGLE chip's styling.
// It cannot be dropped into a Text concatenation to achieve inline flow —
// see §2.3 of the urgency/entity PRD. EntityTitleView's NSTextAttachment
// renderer reproduces these exact metrics.
struct EntityChipReference: View {
    let kind: EntityKind
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            if let symbol = DSEntityChip.sfSymbol(for: kind) {
                Image(systemName: symbol).font(.system(size: 10))
            }
            Text(label)
                .font(kind == .code ? .system(size: 12, design: .monospaced) : .system(size: 12))
        }
        .foregroundColor(DSEntityChip.text(for: kind))
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .background(DSEntityChip.background(for: kind))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(DSEntityChip.border(for: kind), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
