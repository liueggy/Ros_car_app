import SwiftUI

struct JoystickControl: View {
    var speed: Double
    var onCommand: (Double, Double, Double) -> Void
    var onStop: () -> Void
    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 72

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .secondarySystemBackground)).frame(width: radius * 2, height: radius * 2)
            Circle().stroke(.blue.opacity(0.35), lineWidth: 2).frame(width: radius * 2, height: radius * 2)
            Circle().fill(.blue).frame(width: 54, height: 54).offset(knob)
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let len = max(1, sqrt(dx*dx + dy*dy))
                let limited = min(radius, len)
                knob = CGSize(width: dx / len * limited, height: dy / len * limited)
                let x = Double(-knob.height / radius) * speed
                let y = Double(-knob.width / radius) * speed
                onCommand(x, y, 0)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { knob = .zero }
                onStop()
            }
        )
    }
}
