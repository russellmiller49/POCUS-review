import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let trendDescription: String
    let systemImage: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                Text(trendDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
}
