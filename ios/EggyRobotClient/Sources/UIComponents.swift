import SwiftUI

enum SpeedMode: String, CaseIterable, Identifiable {
    case low = "低速"
    case normal = "普通"
    case high = "高速"
    var id: String { rawValue }
    var maxSpeed: Double { switch self { case .low: 0.12; case .normal: 0.22; case .high: 0.35 } }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var color: Color = .blue
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
