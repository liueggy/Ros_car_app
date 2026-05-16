import SwiftUI

struct JoystickControl: View {
    var speed: Double
    var isEnabled: Bool = true
    var onCommand: (Double, Double, Double) -> Void
    var onStop: () -> Void
    @State private var knob: CGSize = .zero
    @State private var currentX: Double = 0
    @State private var currentY: Double = 0
    @State private var isDragging = false
    private let radius: CGFloat = 72
    private let timer = Timer.publish(every: 0.10, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .secondarySystemBackground)).frame(width: radius * 2, height: radius * 2)
            Circle().stroke(isEnabled ? .blue.opacity(0.35) : .gray.opacity(0.25), lineWidth: 2).frame(width: radius * 2, height: radius * 2)
            Circle().stroke(isEnabled ? .blue.opacity(0.18) : .gray.opacity(0.15), lineWidth: 1).frame(width: radius, height: radius)
            Circle().fill(isEnabled ? .blue : .gray.opacity(0.45)).frame(width: 54, height: 54).offset(knob)
            if !isEnabled {
                Label("离线", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isEnabled else { return }
                isDragging = true
                let center = CGPoint(x: radius, y: radius)
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let len = max(1, sqrt(dx*dx + dy*dy))
                let limited = min(radius, len)
                knob = CGSize(width: dx / len * limited, height: dy / len * limited)
                currentX = Double(-knob.height / radius) * speed
                currentY = Double(-knob.width / radius) * speed
                onCommand(currentX, currentY, 0)
            }
            .onEnded { _ in
                isDragging = false
                currentX = 0
                currentY = 0
                withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { knob = .zero }
                onStop()
            }
        )
        .onReceive(timer) { _ in
            if isDragging {
                onCommand(currentX, currentY, 0)
            }
        }
    }
}
