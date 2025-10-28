import SwiftUI

struct FloatingActionButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.headline)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
