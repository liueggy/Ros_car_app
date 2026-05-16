import XCTest
@testable import EggyRobotClient

final class AgentPromptBuilderTests: XCTestCase {
    private let builder = AgentPromptBuilder()

    func testBuildMessagesCreatesSystemStateAndUserMessages() {
        let messages = builder.buildMessages(userText: "小车现在状态如何？", config: AgentConfig(), robot: .noState(connectionStatus: "等待数据"))

        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertTrue(messages[0].content.contains("你必须只返回 JSON"))
        XCTAssertEqual(messages[1].role, "system")
        XCTAssertTrue(messages[1].content.contains("当前机器人状态摘要"))
        XCTAssertTrue(messages[1].content.contains("等待数据"))
        XCTAssertEqual(messages[2].role, "user")
        XCTAssertEqual(messages[2].content, "小车现在状态如何？")
    }

    func testSystemPromptReflectsReadOnlyMode() {
        var config = AgentConfig()
        config.allowRobotControl = false

        let prompt = builder.systemPrompt(config: config)

        XCTAssertTrue(prompt.contains("当前 Agent 控车开关：关闭"))
        XCTAssertTrue(prompt.contains("不要生成 actions"))
    }

    func testSystemPromptIncludesSafetyLimits() {
        var config = AgentConfig()
        config.maxQueueActions = 4
        config.maxLinearSpeed = 0.12
        config.maxAngularSpeed = 0.35
        config.maxActionDuration = 1.2

        let prompt = builder.systemPrompt(config: config)

        XCTAssertTrue(prompt.contains("最多 4 个短动作"))
        XCTAssertTrue(prompt.contains("speed_mps<=0.12"))
        XCTAssertTrue(prompt.contains("angular_rps<=0.35"))
        XCTAssertTrue(prompt.contains("duration_s<=1.2"))
    }

    func testRobotSummaryFormatsSnapshot() {
        let snapshot = AgentPromptRobotSnapshot(
            connectionStatus: "在线",
            robotOnline: true,
            rosOK: true,
            batteryPercent: 86,
            batteryVoltage: 11.87,
            x: 1.23,
            y: -0.45,
            yawRadians: .pi / 2,
            frontDistance: 0.88,
            nearestDistance: 0.42,
            knownMapPercent: 37.6,
            navStatus: "idle",
            autoExplore: true,
            recentLogs: ["log1", "log2"]
        )

        let summary = builder.robotSummary(snapshot)

        XCTAssertTrue(summary.contains("连接状态：在线"))
        XCTAssertTrue(summary.contains("小车在线：是"))
        XCTAssertTrue(summary.contains("电池：86% 11.87V"))
        XCTAssertTrue(summary.contains("yaw=90°"))
        XCTAssertTrue(summary.contains("前方距离：0.88m"))
        XCTAssertTrue(summary.contains("自动探索：运行中"))
        XCTAssertTrue(summary.contains("log1；log2"))
    }
}
