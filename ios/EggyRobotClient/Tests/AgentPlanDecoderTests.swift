import XCTest
@testable import EggyRobotClient

final class AgentPlanDecoderTests: XCTestCase {
    private let decoder = AgentPlanDecoder()

    func testDecodesPlainJSONPlanWithoutActions() throws {
        let plan = try decoder.decodePlan(from: #"{"reply":"状态正常","actions":[]}"#)

        XCTAssertEqual(plan.reply, "状态正常")
        XCTAssertTrue(plan.actionList.isEmpty)
    }

    func testDecodesJSONEmbeddedInText() throws {
        let content = """
        ```json
        {"reply":"准备右转","actions":[{"name":"turn_right_short","requires_confirmation":true,"parameters":{"duration_s":"0.8"}}]}
        ```
        """

        let plan = try decoder.decodePlan(from: content)

        XCTAssertEqual(plan.reply, "准备右转")
        XCTAssertEqual(plan.actionList.count, 1)
        XCTAssertEqual(plan.actionList[0].name, "turn_right_short")
        XCTAssertEqual(plan.actionList[0].parameters["duration_s"], "0.8")
    }

    func testSupportsLegacySingleActionField() throws {
        let content = #"{"reply":"已规划停止","action":{"name":"stop","requires_confirmation":false,"parameters":{}}}"#

        let plan = try decoder.decodePlan(from: content)

        XCTAssertEqual(plan.reply, "已规划停止")
        XCTAssertEqual(plan.actionList.map(\.name), ["stop"])
    }

    func testFallsBackToPlainReplyForNonJSONText() throws {
        let plan = try decoder.decodePlan(from: "小车当前离线，建议检查中转服务器。")

        XCTAssertEqual(plan.reply, "小车当前离线，建议检查中转服务器。")
        XCTAssertTrue(plan.actionList.isEmpty)
    }

    func testExtractsReplyFromStreamingJSONFragment() {
        let visible = decoder.visibleStreamingText(from: #"{"reply":"正在查看小车状态","actions"#)

        XCTAssertEqual(visible, "正在查看小车状态")
    }

    func testShowsPlanningPlaceholderForActionJSONBeforeReplyIsVisible() {
        let visible = decoder.visibleStreamingText(from: #"{"actions":[{"name":"move_forward_short"#)

        XCTAssertEqual(visible, "正在思考并规划动作…")
    }

    func testLeavesPlainStreamingTextVisible() {
        let visible = decoder.visibleStreamingText(from: "正在连接模型")

        XCTAssertEqual(visible, "正在连接模型")
    }
}
