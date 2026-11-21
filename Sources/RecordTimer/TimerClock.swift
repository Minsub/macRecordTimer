import Foundation

enum TimerClock {
    static func elapsedSeconds(startUptime: TimeInterval, nowUptime: TimeInterval, offset: TimeInterval = 0) -> Int {
        max(0, Int(offset + nowUptime - startUptime))
    }

    static func isEmphasized(elapsedSeconds: Int, thresholdSeconds: Int) -> Bool {
        elapsedSeconds >= max(1, thresholdSeconds)
    }

    static func blinkPhase(uptime: TimeInterval, interval: TimeInterval = 0.35) -> Bool {
        Int(uptime / interval).isMultiple(of: 2)
    }
}
