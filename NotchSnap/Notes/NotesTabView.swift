import SwiftUI

// MARK: - NotesTabView — quick notes + Apple Reminders inside the notch
//
// Left: composer (auto-saving draft) with a "Make reminder" toggle and due
// picker — committing with the reminder on creates a real EKReminder in the
// NotchSnap list (syncs with Apple's Reminders app). Right: upcoming
// reminders with complete toggles, then recent notes (click to edit,
// right-click to copy/delete). Permission-denied degrades to a message
// with a System Settings deep link, never a silent failure.

struct NotesTabView: View {
    @ObservedObject private var notes = NotesStore.shared
    @ObservedObject private var reminders = ReminderStore.shared

    @ObservedObject private var appState = AppState.shared
    @State private var makeReminder = false
    @State private var dueDate = NotesTabView.defaultDue()
    @FocusState private var composerFocused: Bool

    private var draftIsEmpty: Bool {
        notes.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Default due time: the next full hour.
    static func defaultDue() -> Date {
        let cal = Calendar.current
        let next = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return cal.date(bySetting: .minute, value: 0, of: next) ?? next
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            composer
                .frame(maxWidth: .infinity)

            rightColumn
                .frame(width: 210)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .task {
            if reminders.access == .granted {
                await reminders.refresh()
            }
        }
        .onAppear { consumeFocusRequest() }
        .onChange(of: appState.focusNotesComposer) { _ in consumeFocusRequest() }
    }

    /// ⌃⇧N wants the caret in the composer immediately. Small delay lets
    /// the expand animation land and the panel become key first.
    private func consumeFocusRequest() {
        guard appState.focusNotesComposer else { return }
        appState.focusNotesComposer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            composerFocused = true
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if notes.draft.isEmpty {
                    Text(L10n.t("notes.placeholder"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                        .padding(.leading, 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes.draft)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .focused($composerFocused)
                    .onChange(of: notes.draft) { _ in notes.draftChanged() }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(composerFocused ? 0.25 : 0.12), lineWidth: 1)
            )
            .frame(maxHeight: .infinity)

            HStack(spacing: 8) {
                Toggle(isOn: $makeReminder) {
                    HStack(spacing: 5) {
                        Image(systemName: "bell")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.t("notes.makeReminder"))
                            .font(.system(size: 11, weight: .semibold))
                        // Shortcut keycap, same style as the save button's
                        HStack(spacing: 3) {
                            Text("\u{2318}")
                            Text("R")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.black.opacity(0.25))
                        )
                    }
                    .foregroundStyle(makeReminder ? Color.white : .white.opacity(0.6))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(makeReminder ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08))
                    )
                    .contentShape(Capsule())
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .onChange(of: makeReminder) { on in
                    if on {
                        dueDate = Self.defaultDue()
                        Task { _ = await reminders.requestAccess() }
                    }
                }

                if makeReminder {
                    DatePicker("", selection: $dueDate)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .scaleEffect(0.85, anchor: .leading)
                        .frame(maxWidth: 150, alignment: .leading)
                }

                Spacer()

                Button(action: commit) {
                    HStack(spacing: 6) {
                        Text(L10n.t(makeReminder ? "notes.saveButtonReminder" : "notes.saveButtonNote"))
                            .font(.system(size: 12, weight: .semibold))
                        // The shortcut as two clear keycaps: ⌘ and ↩
                        HStack(spacing: 3) {
                            Text("\u{2318}")
                            Text("\u{21A9}")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.black.opacity(0.25))
                        )
                    }
                    .foregroundStyle(draftIsEmpty ? Color.white.opacity(0.35) : Color.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(draftIsEmpty ? Color.white.opacity(0.08) : Color.green.opacity(0.85))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(draftIsEmpty)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: makeReminder)
        }
    }

    private func commit() {
        let title = notes.draft
            .split(separator: "\n").first.map(String.init) ?? notes.draft
        if makeReminder {
            Task { @MainActor in
                if let id = await reminders.createReminder(title: title, due: dueDate) {
                    notes.commitDraft(promotedReminderID: id)
                    makeReminder = false
                    HapticManager.shared.copyConfirmed()
                }
            }
        } else {
            notes.commitDraft()
        }
    }

    // MARK: - Right column: reminders + note history

    private var rightColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                if reminders.access == .denied {
                    deniedState
                } else {
                    ForEach(reminders.upcoming) { reminder in
                        ReminderRow(reminder: reminder) {
                            Task { await reminders.toggleComplete(reminder.id) }
                        }
                    }
                }

                if !notes.notes.isEmpty {
                    if !reminders.upcoming.isEmpty || reminders.access == .denied {
                        Divider().opacity(0.3).padding(.vertical, 2)
                    }
                    ForEach(notes.notes) { note in
                        NoteRow(note: note)
                    }
                }

                if notes.notes.isEmpty && reminders.upcoming.isEmpty
                    && reminders.access != .denied {
                    Text(L10n.t("notes.emptyList"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                }
            }
        }
    }

    private var deniedState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("notes.remindersDenied"))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.t("notes.openSettings")) {
                ReminderStore.openSystemSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ReminderRow

private struct ReminderRow: View {
    let reminder: UpcomingReminder
    let onToggle: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(reminder.isCompleted ? Color.accentColor : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(reminder.title)
                .font(.system(size: 11))
                .strikethrough(reminder.isCompleted)
                .foregroundStyle(.white.opacity(reminder.isCompleted ? 0.4 : 0.85))
                .lineLimit(1)

            Spacer(minLength: 4)

            if let due = reminder.dueDate {
                Text(Self.dueLabel(due))
                    .font(.system(size: 9))
                    .foregroundStyle(reminder.isOverdue ? Color.red.opacity(0.9) : .white.opacity(0.4))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(hover ? 0.06 : 0))
        )
        .onHover { hover = $0 }
    }

    static func dueLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        if cal.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - NoteRow

private struct NoteRow: View {
    let note: QuickNote
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: note.promotedReminderID != nil ? "bell.fill" : "note.text")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))

            Text(note.firstLine)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(L10n.relativeTime(from: note.updatedAt))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(hover ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { NotesStore.shared.edit(note.id) }
        .contextMenu {
            Button(L10n.t("action.copy")) {
                ClipboardMonitor.shared.skipNextChange()
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(note.content, forType: .string)
                HapticManager.shared.copyConfirmed()
            }
            Button(L10n.t("action.delete"), role: .destructive) {
                NotesStore.shared.delete(note.id)
            }
        }
    }
}
