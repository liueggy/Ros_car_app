import SwiftUI

struct MapPalette {
    let backdrop: Color
    let freeCell: Color
    let occupiedCell: Color
    let gridLine: Color
    let border: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            backdrop = Color(white: 0.10)
            freeCell = Color(white: 0.18)
            occupiedCell = Color(white: 0.92).opacity(0.92)
            gridLine = Color.white.opacity(0.10)
            border = Color.white.opacity(0.12)
        } else {
            backdrop = Color(white: 0.86)
            freeCell = Color.white
            occupiedCell = Color.black.opacity(0.86)
            gridLine = Color.gray.opacity(0.35)
            border = Color.black.opacity(0.10)
        }
    }
}

struct InteractiveRobotMap: View {
    let state: NavViewMessage
    var onGoal: (Double, Double) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let palette = MapPalette(colorScheme: colorScheme)
            RobotMapCanvas(state: state, palette: palette, transform: MapTransform(scale: scale, offset: offset), size: geo.size, onGoal: onGoal)
                .background(palette.backdrop)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.10), radius: 10, y: 6)
                .gesture(dragGesture(size: geo.size))
                .simultaneousGesture(magnifyGesture)
                .overlay(alignment: .topTrailing) {
                    Text("点按设目标 · 双指缩放 · 拖动平移")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button("复位") { withAnimation { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero } }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .padding(8)
                }
        }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { value in
                if abs(value.translation.width) < 4 && abs(value.translation.height) < 4, let state = Optional(state) {
                    // tap-like goal setting
                    let p = screenToWorld(value.location, state: state, size: size)
                    onGoal(p.x, p.y)
                }
                lastOffset = offset
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = min(5, max(0.6, lastScale * value)) }
            .onEnded { _ in lastScale = scale }
    }

    private func screenToWorld(_ location: CGPoint, state: NavViewMessage, size: CGSize) -> (x: Double, y: Double) {
        let w = max(1, size.width)
        let h = max(1, size.height)
        let x0 = (location.x - offset.width - w * (1 - scale) / 2) / scale
        let y0 = (location.y - offset.height - h * (1 - scale) / 2) / scale
        let map = state.map
        let x = map.originX + Double(x0 / w) * map.widthM
        let y = map.originY + Double((h - y0) / h) * map.heightM
        return (x, y)
    }
}

struct MapTransform { var scale: CGFloat; var offset: CGSize }

struct RobotMapCanvas: View {
    let state: NavViewMessage
    let palette: MapPalette
    var transform: MapTransform = MapTransform(scale: 1, offset: .zero)
    var size: CGSize? = nil
    var onGoal: (Double, Double) -> Void = { _, _ in }

    var body: some View {
        Canvas { ctx, canvasSize in
            let size = size ?? canvasSize
            ctx.translateBy(x: transform.offset.width + size.width * (1 - transform.scale) / 2,
                            y: transform.offset.height + size.height * (1 - transform.scale) / 2)
            ctx.scaleBy(x: transform.scale, y: transform.scale)
            draw(ctx: &ctx, size: size)
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading) {
                Text(String(format: "已探索 %.1f%%", state.occupancyGrid?.stats.knownPercent ?? 0))
                Text(String(format: "前方 %.2f m", state.summary.front ?? -1))
            }.font(.caption.monospaced()).padding(8).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding()
        }
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        let map = state.map
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: (x - map.originX) / map.widthM * size.width,
                    y: size.height - (y - map.originY) / map.heightM * size.height)
        }
        if let grid = state.occupancyGrid {
            let cw = size.width / Double(grid.width)
            let ch = size.height / Double(grid.height)
            let stepX = cw < 1 ? min(12, Int(ceil(1 / max(0.0001, cw)))) : 1
            let stepY = ch < 1 ? min(12, Int(ceil(1 / max(0.0001, ch)))) : 1
            let step = max(1, min(12, max(stepX, stepY)))
            for gy in stride(from: 0, to: grid.height, by: step) {
                let blockH = min(step, grid.height - gy)
                for gx in stride(from: 0, to: grid.width, by: step) {
                    let blockW = min(step, grid.width - gx)

                    var blockValue: Int? = nil
                    for by in 0..<blockH {
                        let row = (gy + by) * grid.width
                        for bx in 0..<blockW {
                            let v = grid.data[row + gx + bx]
                            if v > 0 { blockValue = 100; break }
                            if v == 0 { blockValue = 0 }
                        }
                        if blockValue == 100 { break }
                    }

                    guard let blockValue else { continue }
                    let color = blockValue == 0 ? palette.freeCell : palette.occupiedCell
                    let rect = CGRect(
                        x: Double(gx) * cw,
                        y: size.height - Double(gy + blockH) * ch,
                        width: Double(blockW) * cw + 0.5,
                        height: Double(blockH) * ch + 0.5
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        var gridPath = Path()
        for i in 0...12 { let x = size.width * Double(i) / 12; gridPath.move(to: CGPoint(x: x, y: 0)); gridPath.addLine(to: CGPoint(x: x, y: size.height)) }
        for i in 0...10 { let y = size.height * Double(i) / 10; gridPath.move(to: CGPoint(x: 0, y: y)); gridPath.addLine(to: CGPoint(x: size.width, y: y)) }
        ctx.stroke(gridPath, with: .color(palette.gridLine), lineWidth: 0.8)
        drawPath(state.globalPlan.map { p($0.x, $0.y) }, color: .blue, ctx: &ctx)
        drawPath(state.localPlan.map { p($0.x, $0.y) }, color: .yellow, ctx: &ctx, dashed: true)
        for pt in state.lidarPoints {
            let q = p(pt.x, pt.y)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - 1.8, y: q.y - 1.8, width: 3.6, height: 3.6)), with: .color(.cyan.opacity(0.8)))
        }
        let goal = p(state.goal.x, state.goal.y)
        ctx.stroke(Path(ellipseIn: CGRect(x: goal.x - 12, y: goal.y - 12, width: 24, height: 24)), with: .color(.green), lineWidth: 3)
        let rp = p(state.robot.x, state.robot.y)
        var robotShape = Path()
        robotShape.move(to: CGPoint(x: 18, y: 0)); robotShape.addLine(to: CGPoint(x: -12, y: -10)); robotShape.addLine(to: CGPoint(x: -8, y: 0)); robotShape.addLine(to: CGPoint(x: -12, y: 10)); robotShape.closeSubpath()
        var tr = CGAffineTransform(translationX: rp.x, y: rp.y).rotated(by: CGFloat(-state.robot.yaw))
        ctx.fill(robotShape.applying(tr), with: .color(.green))
    }

    private func drawPath(_ points: [CGPoint], color: Color, ctx: inout GraphicsContext, dashed: Bool = false) {
        guard points.count > 1 else { return }
        var path = Path(); path.move(to: points[0]); points.dropFirst().forEach { path.addLine(to: $0) }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, dash: dashed ? [8, 5] : []))
    }
}
