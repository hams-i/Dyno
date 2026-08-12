import AppKit
import SwiftUI

struct TasksTabView: View {
    @ObservedObject var service: TasksService
    @ObservedObject private var prefs = PreferencesStore.shared

    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    private static let spaceBlack = Color(red: 0.17, green: 0.17, blue: 0.18)

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 10) {
                toolbar

                if service.tasks.isEmpty {
                    emptyState(
                        title: L10n.tasksEmptyTitle,
                        hint: L10n.tasksEmptyHint
                    )
                    .frame(minHeight: 120)
                } else if service.filteredTasks.isEmpty {
                    emptyState(
                        title: L10n.tasksEmptyFilterTitle,
                        hint: nil
                    )
                    .frame(minHeight: 120)
                } else {
                    taskList
                }
            }
            .padding(.bottom, 2)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.locale, Locale(identifier: prefs.preferences.languageCode == "tr" ? "tr" : "en"))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField(L10n.tasksPlaceholder, text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isDraftFocused ? Color.black : Color.white.opacity(0.92))
                .tint(isDraftFocused ? Color.black : Color.accentColor)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(isDraftFocused ? Color.white : Color.white.opacity(0.06))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(isDraftFocused ? 0 : 0.08),
                            lineWidth: 0.6
                        )
                }
                .focused($isDraftFocused)
                .onSubmit(submit)
                .onChange(of: isDraftFocused) { _, focused in
                    guard focused else { return }
                    if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
                        if !NSApp.isActive {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        window.makeKeyAndOrderFront(nil)
                    }
                    DispatchQueue.main.async {
                        applyFocusedFieldSelectionChrome()
                    }
                }
                .animation(.snappy(duration: 0.18), value: isDraftFocused)

            Button(action: submit) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Self.spaceBlack)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                            }
                    )
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            .help(L10n.tasksAdd)

            Spacer(minLength: 4)

            filterControl

            if service.tasks.contains(where: \.isCompleted) {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        service.clearCompleted()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.tasksClearCompleted)
            }
        }
    }

    private var filterControl: some View {
        HStack(spacing: 2) {
            ForEach(TasksFilter.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        service.filter = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            service.filter == item
                                ? Color.white
                                : Color.white.opacity(0.42)
                        )
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background {
                            if service.filter == item {
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var taskList: some View {
        VStack(spacing: 6) {
            ForEach(service.filteredTasks) { task in
                TaskRow(
                    task: task,
                    isSelected: service.selectedTaskID == task.id,
                    onSelect: {
                        withAnimation(.snappy(duration: 0.2)) {
                            service.select(task.id)
                        }
                    },
                    onToggle: {
                        withAnimation(.snappy(duration: 0.22)) {
                            service.toggle(task.id)
                        }
                    },
                    onDelete: {
                        withAnimation(.snappy(duration: 0.22)) {
                            service.delete(task.id)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func emptyState(title: String, hint: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.32))
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            if let hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func submit() {
        guard service.add(draft) else { return }
        draft = ""
        isDraftFocused = true
    }

    private func applyFocusedFieldSelectionChrome() {
        guard let window = NSApp.keyWindow,
              let editor = window.firstResponder as? NSTextView else { return }
        editor.selectedTextAttributes = [
            .backgroundColor: NSColor.white,
            .foregroundColor: NSColor.black
        ]
        editor.insertionPointColor = .black
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.white.opacity(0.35)
                            : Color.white.opacity(0.72)
                    )
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? L10n.tasksFilterActive : L10n.tasksFilterCompleted)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.white.opacity(0.38)
                            : Color.white.opacity(0.92)
                    )
                    .strikethrough(task.isCompleted, color: .white.opacity(0.35))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(timestampLine)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.32))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Genişlik sabit — hover’da layout kaymasın.
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.tasksDelete)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(rowStroke, lineWidth: isSelected ? 1.1 : 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
        .animation(.snappy(duration: 0.18), value: isHovering)
        .animation(.snappy(duration: 0.18), value: isSelected)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(L10n.tasksShowOnIsland, systemImage: "dock.rectangle", action: onSelect)
            Button(
                task.isCompleted ? L10n.tasksFilterActive : L10n.tasksFilterCompleted,
                systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle",
                action: onToggle
            )
            Divider()
            Button(L10n.tasksDelete, systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var rowFill: Color {
        if isSelected { return Color.white.opacity(0.12) }
        if isHovering { return Color.white.opacity(0.08) }
        return Color.white.opacity(0.04)
    }

    private var rowStroke: Color {
        if isSelected { return Color.accentColor.opacity(0.7) }
        if isHovering { return Color.white.opacity(0.14) }
        return Color.white.opacity(0.05)
    }

    private var timestampLine: String {
        var parts: [String] = [
            L10n.tasksCreatedAt(Self.stampFormatter.string(from: task.createdAt))
        ]
        if task.isCompleted, let completedAt = task.completedAt {
            parts.append(L10n.tasksCompletedAt(Self.stampFormatter.string(from: completedAt)))
        }
        return parts.joined(separator: " · ")
    }
}
