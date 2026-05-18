import Foundation

@MainActor
protocol RobotControlling: AnyObject {
    var canSendCommands: Bool { get }
    var isRobotOnline: Bool { get }
    var frontDistance: Double? { get }
    var isAutoExploreRunning: Bool { get }

    func cmd(x: Double, y: Double, z: Double)
    func stop()
    func toggleExplore()
    func saveMap(name: String)
    func reset()
    func startMapping()
    func stopMapping()
    func saveNavigationMap(name: String)
    func startQuickDirectNavigation()
    func startMoveBaseNavigation(mapPath: String?)
    func stopNavigation()
    func setMode(_ mode: String)
    func sendRawCommand(_ dict: [String: Any])
}

extension RobotViewModel: RobotControlling {
    var canSendCommands: Bool { phase.canSend }
    var isRobotOnline: Bool { robotOnline }
    var frontDistance: Double? { state?.summary.front }
    var isAutoExploreRunning: Bool { state?.system.autoExplore == true }
    func sendRawCommand(_ dict: [String: Any]) { send(dict) }
}
