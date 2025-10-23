import SwiftUI

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4, y: 2)
        )
        .padding(.horizontal)
    }
}

#Preview {
    ErrorBanner(message: "Upload failed to complete.", dismiss: {})
}
