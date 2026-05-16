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
            Text(value).font(.title2.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatusPill: View {
    let title: String
    let value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct InlineNotice: View {
    let text: String
    let systemImage: String
    var color: Color

    init(_ text: String, systemImage: String, color: Color = .orange) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
