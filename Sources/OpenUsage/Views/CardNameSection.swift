import SwiftUI

/// The card's name in its Customize detail — the discoverable twin of the dashboard's inline rename.
/// Return or a click elsewhere saves, and Esc restores the saved name. An empty field restores the
/// generated name, which the placeholder shows; "Restore" does the same in one click.
struct CardNameSection: View {
    let providerID: String
    @Environment(LayoutStore.self) private var layout
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: density.headerToCardSpacing) {
            Text("Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            HStack(spacing: 8) {
                TextField(layout.generatedName(for: providerID) ?? "", text: $draft)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isFocused)
                    .onSubmit { save() }
                    .onExitCommand {
                        draft = savedName
                        isFocused = false
                    }
                    .accessibilityLabel("Card Name")
                if layout.hasCustomName(providerID) {
                    Button("Restore") {
                        layout.renameProvider(providerID, to: "")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .hoverTooltip("Use the name \u{201C}\(layout.generatedName(for: providerID) ?? "")\u{201D}")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, density.controlRowPadding)
            .cardSurface()
        }
        .onAppear { draft = savedName }
        .onChange(of: isFocused) { wasFocused, isFocusedNow in
            if wasFocused, !isFocusedNow { save() }
        }
        // Follow renames made elsewhere (the dashboard header), unless the user is typing here.
        .onChange(of: savedName) { _, name in
            if !isFocused { draft = name }
        }
    }

    private var savedName: String {
        layout.provider(id: providerID)?.displayName ?? ""
    }

    private func save() {
        layout.renameProvider(providerID, to: draft)
        draft = savedName
    }
}
