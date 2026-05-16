import XCTest
@testable import EggyRobotClient

@MainActor
final class RobotToolExecutorTests: XCTestCase {
    func testStopAlwaysSendsStop() async {
        let robot = FakeRobotController(canSendCommands: false, isRobotOnline: false)
        let executor = RobotToolExecutor(robot: robot)

        let result = await executor.execute(action("stop"), config: AgentConfig())

        XCTAssertEqual(result, "已发送急停/停止命令。")
        XCTAssertEqual(robot.stopCount, 1)
    }

    func testMoveRejectsWhenRobotOffline() async {
        let robot = FakeRobotController(canSendCommands: true, isRobotOnline: false)
        let executor = RobotToolExecutor(robot: robot)

        let result = await executor.execute(action("move_forward_short"), config: AgentConfig())

        XCTAssertEqual(result, "小车未在线，移动命令未执行。")
        XCTAssertTrue(robot.commands.isEmpty)
    }

    func testMoveForwardRejectsWhenObstacleTooClose() async {
        let robot = FakeRobotController(frontDistance: 0.30)
        let executor = RobotToolExecutor(robot: robot)
        var config = AgentConfig()
        config.obstacleStopDistance = 0.55

        let result = await executor.execute(action("move_forward_short"), config: config)

        XCTAssertTrue(result.contains("前方障碍 0.30m"))
        XCTAssertTrue(robot.commands.isEmpty)
    }

    func testMoveForwardClampsSpeedAndStops() async {
        let robot = FakeRobotController()
        let executor = RobotToolExecutor(robot: robot)
        var config = AgentConfig()
        config.maxLinearSpeed = 0.10
        config.maxActionDuration = 0.2

        let result = await executor.execute(action("move_forward_short", parameters: ["speed_mps": "0.50", "duration_s": "3.0"]), config: config)

        XCTAssertEqual(robot.commands.first?.x ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(robot.commands.first?.y ?? 0, 0, accuracy: 0.0001)
        XCTAssertEqual(robot.commands.first?.z ?? 0, 0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(robot.stopCount, 1)
        XCTAssertEqual(result, "已执行短动作 0.2s，并自动停止。")
    }

    func testStartAutoExploreRequiresOnlineRobot() async {
        let robot = FakeRobotController(canSendCommands: true, isRobotOnline: false)
        let executor = RobotToolExecutor(robot: robot)

        let result = await executor.execute(action("start_auto_explore"), config: AgentConfig())

        XCTAssertEqual(result, "小车未在线，不能开始自动探索。")
        XCTAssertEqual(robot.toggleExploreCount, 0)
    }

    func testStartAutoExploreTogglesWhenOnline() async {
        let robot = FakeRobotController()
        let executor = RobotToolExecutor(robot: robot)

        let result = await executor.execute(action("start_auto_explore"), config: AgentConfig())

        XCTAssertEqual(result, "已请求开始自动探索。")
        XCTAssertEqual(robot.toggleExploreCount, 1)
    }

    func testUnsupportedActionReturnsMessage() async {
        let robot = FakeRobotController()
        let executor = RobotToolExecutor(robot: robot)

        let result = await executor.execute(action("dance"), config: AgentConfig())

        XCTAssertEqual(result, "暂不支持动作：dance")
    }

    private func action(_ name: String, parameters: [String: String] = [:]) -> AgentAction {
        AgentAction(name: name, requiresConfirmation: true, parameters: parameters)
    }
}

@MainActor
private final class FakeRobotController: RobotControlling {
    var canSendCommands: Bool
    var isRobotOnline: Bool
    var frontDistance: Double?
    var isAutoExploreRunning: Bool
    var commands: [(x: Double, y: Double, z: Double)] = []
    var stopCount = 0
    var toggleExploreCount = 0
    var savedMapNames: [String] = []
    var resetCount = 0

    init(canSendCommands: Bool = true, isRobotOnline: Bool = true, frontDistance: Double? = nil, isAutoExploreRunning: Bool = false) {
        self.canSendCommands = canSendCommands
        self.isRobotOnline = isRobotOnline
        self.frontDistance = frontDistance
        self.isAutoExploreRunning = isAutoExploreRunning
    }

    func cmd(x: Double, y: Double, z: Double) { commands.append((x, y, z)) }
    func stop() { stopCount += 1 }
    func toggleExplore() { toggleExploreCount += 1; isAutoExploreRunning.toggle() }
    func saveMap(name: String) { savedMapNames.append(name) }
    func reset() { resetCount += 1 }
}
