import XCTest
@testable import EggyRobotClient

final class RobotCommandEncoderTests: XCTestCase {
    private let encoder = RobotCommandEncoder()

    func testEncodesVelocityCommand() {
        let payload = encoder.encode(.velocity(x: 0.12, y: -0.03, z: 0.45))

        XCTAssertEqual(payload["type"] as? String, "cmd_vel")
        XCTAssertEqual(payload["linear_x"] as? Double, 0.12)
        XCTAssertEqual(payload["linear_y"] as? Double, -0.03)
        XCTAssertEqual(payload["angular_z"] as? Double, 0.45)
    }

    func testEncodesGoalCommand() {
        let payload = encoder.encode(.goal(x: 1.2, y: -0.8))

        XCTAssertEqual(payload["type"] as? String, "goal")
        XCTAssertEqual(payload["frame_id"] as? String, "map")
        XCTAssertEqual(payload["x"] as? Double, 1.2)
        XCTAssertEqual(payload["y"] as? Double, -0.8)
        XCTAssertEqual(payload["yaw"] as? Double, 0)
    }

    func testEncodesAutoExploreCommand() {
        let payload = encoder.encode(.autoExplore(enabled: true))

        XCTAssertEqual(payload["type"] as? String, "auto_explore")
        XCTAssertEqual(payload["enabled"] as? Bool, true)
    }

    func testEncodesMapCommands() {
        XCTAssertEqual(encoder.encode(.saveMap(name: "客厅"))["name"] as? String, "客厅")
        XCTAssertEqual(encoder.encode(.loadMap(id: "map-1"))["id"] as? String, "map-1")
        XCTAssertEqual(encoder.encode(.deleteMap(id: "map-2"))["type"] as? String, "delete_map")
    }

    func testEncodesPingCommand() {
        let payload = encoder.encode(.ping())

        XCTAssertEqual(payload["type"] as? String, "ping")
        XCTAssertEqual(payload["client"] as? String, "ios")
    }
}
