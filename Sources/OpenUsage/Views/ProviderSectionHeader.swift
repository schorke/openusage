import SwiftUI

/// Shared provider section header used by the dashboard and its lifted provider-reorder preview.
/// The provider mark and name lead, followed by the optional plan badge. Dashboard callers supply a
/// screenshot-copy action, revealed at the trailing edge while the header is hovered. Callers can also
/// supply an optional `warning` — the latest refresh error, rendered as a small amber
/// triangle beside the name whose hover tooltip carries the message (e.g. "Not logged in. Run `codex`
/// to authenticate."). The
/// optional `staleness` is the dashboard-only hint that the values shown are an aged snapshot still
/// revalidating: a short "Outdated" tag whose hover tooltip carries the precise age ("Last updated 3h
/// 12m ago"), so fossilized plan/limits never pass for current data.
struct ProviderSectionHeader: View {
    let provider: Provider
    var plan: String?
    var warning: String?
    /// Whether this provider's refresh is currently in flight — drives the small spinner beside the name
    /// so the section shows live feedback while values are being fetched (instead of silently sitting on
    /// the previous, possibly stale, numbers).
    var refreshing: Bool = false
    /// A muted "Outdated" hint shown only when the displayed snapshot has aged past its freshness window
    /// (dashboard only; `nil` in the reorder preview, which never surfaces staleness). Its tooltip carries
    /// the precise age.
    var staleness: StalenessHint?
    /// Dashboard-only screenshot action. The reorder preview omits it, while Customize uses its own
    /// row type and is unaffected by this header.
    var onCopyScreenshot: (() -> Bool)?
    /// Dashboard-only inline rename. While it is `true`, a text field replaces the name. A double-click
    /// on the name sets it; the caller's context menu sets it too. `nil` in the reorder preview.
    var isRenaming: Binding<Bool>?
    /// The name an empty rename restores — shown as the field's placeholder.
    var generatedName: String?
    /// Saves the edited name. A blank name restores `generatedName`.
    var onRename: ((String) -> Void)?

    /// Header type and icon track the density setting like the rows do, so Compact shrinks the
    /// whole section anatomy — not just the rows under it.
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular
    /// Party easter egg: pulse the provider mark. Off by default everywhere else.
    @Environment(\.popoverPartyMode) private var partyMode
    @State private var isHovered = false

    init(
        provider: Provider,
        plan: String? = nil,
        warning: String? = nil,
        refreshing: Bool = false,
        staleness: StalenessHint? = nil,
        onCopyScreenshot: (() -> Bool)? = nil,
        isRenaming: Binding<Bool>? = nil,
        generatedName: String? = nil,
        onRename: ((String) -> Void)? = nil
    ) {
        self.provider = provider
        self.plan = plan
        self.warning = warning
        self.refreshing = refreshing
        self.staleness = staleness
        self.onCopyScreenshot = onCopyScreenshot
        self.isRenaming = isRenaming
        self.generatedName = generatedName
        self.onRename = onRename
    }

    var body: some View {
        HStack(spacing: 5) {
            // The provider mark replaces the dashboard's visual drag grip. Reordering still belongs
            // to the whole header at the caller, so the logo itself stays presentational.
            ProviderIcon(source: provider.icon, inset: 0.04)
                .frame(width: density.headerIconSize, height: density.headerIconSize)
                .partyPulse(partyMode)
            // Baseline-aligned pair: the plan badge (and stale tag) are smaller type and sit on the
            // name's text baseline, so the words line up along the bottom rather than floating centered.
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                // Give the plan first choice of the available width, while still allowing an oversized
                // plan to truncate. Account names and the lower-priority stale tag yield space first.
                name
                    .layoutPriority(1)
                if let plan {
                    ProviderPlanBadge(plan: plan)
                        .layoutPriority(2)
                }
                // Tertiary, below the plan in hierarchy: outdated content, not something the user acts on.
                // Short by design ("Outdated") so it never pushes the plan name onto a second line — the
                // precise age rides in the hover tooltip. Hidden while a refresh is in flight: the spinner
                // already says "working on it".
                if let staleness, !refreshing {
                    Text(staleness.label)
                        .font(.system(size: density.planBadgePointSize))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .hoverTooltip(staleness.tooltip)
                }
            }
            if refreshing {
                MotionAwareProgressView(controlSize: .mini)
                    .accessibilityLabel("Refreshing")
            } else if let warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.notice)
                    .hoverTooltip(warning)
                    .accessibilityLabel(warning)
            }
            Spacer(minLength: 8)
            if let onCopyScreenshot {
                CopyFeedbackButton(
                    accessibilityLabel: "Copy \(provider.displayName) Screenshot",
                    isRevealed: isHovered,
                    action: onCopyScreenshot
                )
            }
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var name: some View {
        if let isRenaming, let onRename, isRenaming.wrappedValue {
            CardNameField(
                name: provider.displayName,
                placeholder: generatedName ?? provider.displayName,
                pointSize: density.headerPointSize,
                onCommit: { newName in
                    isRenaming.wrappedValue = false
                    onRename(newName)
                },
                onCancel: { isRenaming.wrappedValue = false }
            )
        } else if let isRenaming, onRename != nil {
            nameText
                .onTapGesture(count: 2) { isRenaming.wrappedValue = true }
                .accessibilityAction(named: "Rename") { isRenaming.wrappedValue = true }
        } else {
            nameText
        }
    }

    private var nameText: some View {
        Text(provider.displayName)
            .font(.system(size: density.headerPointSize, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

/// The inline editor that replaces a card's name during a rename, in the same type as the name so
/// nothing moves. It works like a Finder rename: Return saves, Esc cancels, and a click elsewhere
/// saves. The placeholder shows the generated name, which an empty field restores.
struct CardNameField: View {
    let name: String
    let placeholder: String
    let pointSize: CGFloat
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var draft = ""
    /// Set by the first of Return, Esc, or focus loss, so one edit never saves twice.
    @State private var isFinished = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: pointSize, weight: .semibold))
            .lineLimit(1)
            .focused($isFocused)
            .onSubmit { finish(save: true) }
            .onExitCommand { finish(save: false) }
            .onChange(of: isFocused) { wasFocused, isFocusedNow in
                if wasFocused, !isFocusedNow { finish(save: true) }
            }
            .onAppear {
                draft = name
                // The popover panel takes focus a moment after the field appears, so focus next turn.
                Task { @MainActor in isFocused = true }
            }
            .accessibilityLabel("Card Name")
    }

    private func finish(save: Bool) {
        guard !isFinished else { return }
        isFinished = true
        if save { onCommit(draft) } else { onCancel() }
    }
}

struct ProviderPlanBadge: View {
    let plan: String

    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    var body: some View {
        // Plain text — no pill/capsule — for a cleaner header. Secondary (not tertiary): the plan
        // name is information the user reads, and tertiary on glass is reserved for inactive
        // content. The smaller point size alone keeps it subordinate to metric values.
        Text(plan)
            .font(.system(size: density.planBadgePointSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

struct ReorderGrip: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 16, height: 22)
            .contentShape(Rectangle())
    }
}
