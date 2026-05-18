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

struct AppSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var accent: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            content
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(.separator).opacity(0.25)))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
}

struct ActionRowButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var role: ButtonRole?
    var isEnabled = true
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 30, height: 30)
                    .background(iconColor.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var iconColor: Color {
        role == .destructive ? .red : .accentColor
    }
}

struct TimelineStepBadge: View {
    let number: Int
    var isActive: Bool = true

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .foregroundStyle(isActive ? .white : .secondary)
            .frame(width: 24, height: 24)
            .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
    }
}

struct CapsuleTag: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
