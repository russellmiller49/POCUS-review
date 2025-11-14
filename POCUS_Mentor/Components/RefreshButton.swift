import SwiftUI

struct RefreshButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isBusy)
        .accessibilityLabel("Refresh data")
    }
}

#Preview {
    RefreshButton(isBusy: false, action: {})
}
