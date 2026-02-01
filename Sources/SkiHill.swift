import SwiftUI

enum SkiHill: CaseIterable {
    case normalHill
    case largeHill
    case skiFlying

    var name: String {
        switch self {
        case .normalHill: return "Normal Hill"
        case .largeHill: return "Large Hill"
        case .skiFlying: return "Ski Flying Hill"
        }
    }

    var description: String {
        switch self {
        case .normalHill: return "Beginner friendly - Perfect for learning"
        case .largeHill: return "Standard Olympic event"
        case .skiFlying: return "Extreme distances - For experts only"
        }
    }

    var kPoint: Int {
        switch self {
        case .normalHill: return 90
        case .largeHill: return 120
        case .skiFlying: return 185
        }
    }

    var hillSize: Int {
        switch self {
        case .normalHill: return 100
        case .largeHill: return 140
        case .skiFlying: return 225
        }
    }

    var difficulty: String {
        switch self {
        case .normalHill: return "BEGINNER"
        case .largeHill: return "INTERMEDIATE"
        case .skiFlying: return "EXPERT"
        }
    }

    var difficultyColor: Color {
        switch self {
        case .normalHill: return .green
        case .largeHill: return .yellow
        case .skiFlying: return .red
        }
    }

    // Inrun (approach) parameters
    var inrunLength: Float {
        switch self {
        case .normalHill: return 80
        case .largeHill: return 100
        case .skiFlying: return 130
        }
    }

    var inrunAngle: Float {
        switch self {
        case .normalHill: return 35
        case .largeHill: return 35
        case .skiFlying: return 37
        }
    }

    // Takeoff table parameters
    var takeoffAngle: Float {
        switch self {
        case .normalHill: return 11
        case .largeHill: return 11
        case .skiFlying: return 10.5
        }
    }

    // Landing hill parameters
    var landingHillAngle: Float {
        switch self {
        case .normalHill: return 35
        case .largeHill: return 35
        case .skiFlying: return 38
        }
    }

    // Starting gate height (affects speed)
    var startingGateHeight: Float {
        switch self {
        case .normalHill: return 2.5
        case .largeHill: return 3.0
        case .skiFlying: return 3.5
        }
    }

    // Points per meter beyond K-point
    var pointsPerMeter: Float {
        switch self {
        case .normalHill: return 2.0
        case .largeHill: return 1.8
        case .skiFlying: return 1.2
        }
    }

    // Base points at K-point
    var basePoints: Float {
        return 60.0
    }
}
