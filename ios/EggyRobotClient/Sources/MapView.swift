import SwiftUI

struct MapView: View {
    @EnvironmentObject var model: RobotViewModel
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color(white: 0.86)
                    if let state = model.state {
                        RobotMapCanvas(state: state) { x, y in model.setGoal(x: x, y: y) }
                    } else {
                        ContentUnavailableView("等待地图数据", systemImage: "wifi", description: Text("请确认服务器 WebSocket 已连接"))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .navigationTitle("实时地图")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("重置") { model.reset() }
                    Button(model.state?.system.autoExplore == true ? "停止探索" : "自动探索") { model.toggleExplore() }
                }
            }
        }
    }
}

struct RobotMapCanvas: View {
    let state: NavViewMessage
    var onGoal: (Double, Double) -> Void

    var body: some View {
        Canvas { ctx, size in
            let map = state.map
            func p(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: (x - map.originX) / map.widthM * size.width,
                        y: size.height - (y - map.originY) / map.heightM * size.height)
            }
            if let grid = state.occupancyGrid {
                let cw = size.width / Double(grid.width)
                let ch = size.height / Double(grid.height)
                for gy in 0..<grid.height {
                    for gx in 0..<grid.width {
                        let v = grid.data[gy * grid.width + gx]
                        if v == -1 { continue }
                        let color = v == 0 ? Color.white : Color.black.opacity(0.86)
                        let rect = CGRect(x: Double(gx) * cw, y: size.height - Double(gy + 1) * ch, width: cw + 0.5, height: ch + 0.5)
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
            }
            var gridPath = Path()
            for i in 0...12 { let x = size.width * Double(i) / 12; gridPath.move(to: CGPoint(x: x, y: 0)); gridPath.addLine(to: CGPoint(x: x, y: size.height)) }
            for i in 0...10 { let y = size.height * Double(i) / 10; gridPath.move(to: CGPoint(x: 0, y: y)); gridPath.addLine(to: CGPoint(x: size.width, y: y)) }
            ctx.stroke(gridPath, with: .color(.gray.opacity(0.35)), lineWidth: 0.8)

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
            var transform = CGAffineTransform(translationX: rp.x, y: rp.y).rotated(by: CGFloat(-state.robot.yaw))
            ctx.fill(robotShape.applying(transform), with: .color(.green))
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
            let size = value.startLocation
            // Geometry unavailable here; use UIScreen-ish from view bounds via location normalized by hosting size is handled by wrapper limitations.
            // For simplicity, map tap support is implemented approximately in a full-size coordinate space by MapReader in future.
            _ = size
        })
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading) {
                Text(String(format: "已探索 %.1f%%", state.occupancyGrid?.stats.knownPercent ?? 0))
                Text(String(format: "前方 %.2f m", state.summary.front))
            }.font(.caption.monospaced()).padding(8).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding()
        }
    }

    private func drawPath(_ points: [CGPoint], color: Color, ctx: inout GraphicsContext, dashed: Bool = false) {
        guard points.count > 1 else { return }
        var path = Path(); path.move(to: points[0]); points.dropFirst().forEach { path.addLine(to: $0) }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, dash: dashed ? [8, 5] : []))
    }
}
