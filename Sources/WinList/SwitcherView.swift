import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void
    let onActivate: (WindowItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)

            if !model.hasAccessibilityPermission {
                permissionView
            } else if model.windows.isEmpty {
                emptyView
            } else {
                windowList
            }

            Divider().opacity(0.45)
            footer
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .padding(1)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(.tint)
            Text("Open Windows")
                .font(.headline)
            Spacer()
            Text("\(model.windows.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.secondary.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        WindowRow(
                            window: window,
                            isSelected: index == model.selectedIndex
                        )
                        .id(window.id)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                model.selectedIndex = index
                            }
                        }
                        .onTapGesture {
                            model.selectedIndex = index
                            onActivate(window)
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selectedIndex) { index in
                guard model.windows.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(model.windows[index].id, anchor: .center)
                }
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text("Accessibility Access Required")
                .font(.headline)
            Text("WinList needs permission to discover every window and focus the selected one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Open Windows")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            ShortcutHint(keys: "↑ ↓", label: "select")
            ShortcutHint(keys: "↩", label: "open")
            Spacer()
            ShortcutHint(keys: "esc", label: "close")
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}

private struct WindowRow: View {
    let window: WindowItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: window.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(window.applicationName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if window.isFocused {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.tint, in: Capsule())
                    }
                    if window.isMinimized {
                        Image(systemName: "minus.rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(window.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
            }
        }
    }
}

private struct ShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.caption.monospaced().weight(.semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
