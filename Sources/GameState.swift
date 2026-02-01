import Foundation
import Combine

enum GamePhase {
    case ready
    case inrun
    case takeoff
    case flight
    case landing
    case landed
    case finished
}

class GameState: ObservableObject {
    @Published var phase: GamePhase = .ready
    @Published var currentSpeed: Float = 0
    @Published var jumpDistance: Float = 0
    @Published var displayMessage: String? = nil

    // Wind conditions
    @Published var windSpeed: Float = 0
    @Published var windDirection: String = "→"

    // Scoring
    @Published var distancePoints: Float = 0
    @Published var styleScores: [Float] = [0, 0, 0, 0, 0]
    @Published var totalStylePoints: Float = 0
    @Published var totalScore: Float = 0

    // Player state
    @Published var leanAngle: Float = 0  // Forward/backward lean
    @Published var balanceOffset: Float = 0  // Left/right balance
    @Published var isPreparingLanding: Bool = false

    // Jump quality metrics
    var takeoffTiming: Float = 0  // -1 to 1, 0 is perfect
    var flightFormQuality: Float = 1.0  // 0 to 1
    var landingQuality: Float = 1.0  // 0 to 1

    init() {
        generateWindConditions()
    }

    func generateWindConditions() {
        windSpeed = Float.random(in: 0...3.5)
        let directions = ["↑ Head", "↓ Tail", "← Cross", "→ Cross"]
        windDirection = directions.randomElement() ?? "→ Cross"
    }

    func reset() {
        phase = .ready
        currentSpeed = 0
        jumpDistance = 0
        displayMessage = nil
        distancePoints = 0
        styleScores = [0, 0, 0, 0, 0]
        totalStylePoints = 0
        totalScore = 0
        leanAngle = 0
        balanceOffset = 0
        isPreparingLanding = false
        takeoffTiming = 0
        flightFormQuality = 1.0
        landingQuality = 1.0
        generateWindConditions()
    }

    func calculateScore(for hill: SkiHill) {
        // Distance points
        let distanceFromK = jumpDistance - Float(hill.kPoint)
        distancePoints = hill.basePoints + (distanceFromK * hill.pointsPerMeter)
        distancePoints = max(0, distancePoints)

        // Style scores from 5 judges (max 20 each)
        // Based on: takeoff timing, flight form, landing quality
        let baseStyle: Float = 15.0
        let takeoffBonus = (1.0 - abs(takeoffTiming)) * 2.0
        let flightBonus = flightFormQuality * 2.0
        let landingBonus = landingQuality * 2.0

        for i in 0..<5 {
            // Add some variation between judges
            let variation = Float.random(in: -0.5...0.5)
            var score = baseStyle + takeoffBonus + flightBonus + landingBonus + variation

            // Clamp to valid range
            score = min(20.0, max(0, score))
            styleScores[i] = score
        }

        // Sort and remove highest/lowest
        let sortedScores = styleScores.sorted()
        let middleScores = Array(sortedScores[1..<4])
        totalStylePoints = middleScores.reduce(0, +)

        // Wind compensation
        var windCompensation: Float = 0
        if windDirection.contains("Head") {
            windCompensation = windSpeed * 1.5  // Headwind helps, so reduce points
        } else if windDirection.contains("Tail") {
            windCompensation = -windSpeed * 1.5  // Tailwind hurts, so add points
        }

        totalScore = distancePoints + totalStylePoints + windCompensation
    }

    func showMessage(_ message: String, duration: TimeInterval = 2.0) {
        displayMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.displayMessage == message {
                self?.displayMessage = nil
            }
        }
    }
}
