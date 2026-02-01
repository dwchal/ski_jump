import SwiftUI
import SceneKit

struct GameView: View {
    let hill: SkiHill
    let onBack: () -> Void

    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            // 3D Scene
            SkiJumpSceneView(hill: hill, gameState: gameState)
                .ignoresSafeArea()

            // HUD Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Menu")
                        }
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])

                    Spacer()

                    // Hill info
                    VStack(alignment: .trailing) {
                        Text(hill.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("K-\(hill.kPoint) | HS-\(hill.hillSize)")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                }
                .padding()

                Spacer()

                // Center messages
                if let message = gameState.displayMessage {
                    Text(message)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 4, x: 2, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Bottom HUD
                HStack(alignment: .bottom) {
                    // Speed indicator
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SPEED")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(Int(gameState.currentSpeed)) km/h")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)

                    Spacer()

                    // Distance (shown after jump)
                    if gameState.phase == .landed || gameState.phase == .finished {
                        VStack(spacing: 5) {
                            Text("DISTANCE")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(String(format: "%.1f m", gameState.jumpDistance))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(gameState.jumpDistance >= Float(hill.kPoint) ? .green : .yellow)
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    }

                    Spacer()

                    // Wind indicator
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("WIND")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            Text(gameState.windDirection)
                                .font(.caption)
                            Text(String(format: "%.1f m/s", gameState.windSpeed))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(gameState.windSpeed > 2 ? .red : .white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                }
                .padding()

                // Score display after landing
                if gameState.phase == .finished {
                    ScoreCardView(gameState: gameState, hill: hill, onRestart: {
                        gameState.reset()
                    }, onBack: onBack)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Controls hint
                if gameState.phase == .ready {
                    Text("Press SPACE to start")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }

                if gameState.phase == .inrun {
                    Text("Press SPACE at the edge to jump!")
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }

                if gameState.phase == .flight {
                    VStack {
                        Text("W/S: Lean | A/D: Balance")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("SPACE to prepare landing")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: gameState.phase)
        }
    }
}

struct ScoreCardView: View {
    @ObservedObject var gameState: GameState
    let hill: SkiHill
    let onRestart: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("JUMP COMPLETE")
                .font(.title.bold())
                .foregroundColor(.white)

            Divider().background(Color.white)

            HStack(spacing: 40) {
                VStack {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.1f m", gameState.jumpDistance))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                VStack {
                    Text("Distance Points")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.1f", gameState.distancePoints))
                        .font(.title2.bold())
                        .foregroundColor(.cyan)
                }
            }

            // Style judges
            VStack(spacing: 5) {
                Text("Style Points (Judges)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 15) {
                    ForEach(0..<5) { index in
                        VStack {
                            Text("J\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                            Text(String(format: "%.1f", gameState.styleScores[index]))
                                .font(.headline)
                                .foregroundColor(styleColor(for: gameState.styleScores[index]))
                        }
                    }
                }

                Text(String(format: "Style Total: %.1f", gameState.totalStylePoints))
                    .font(.headline)
                    .foregroundColor(.yellow)
            }

            Divider().background(Color.white)

            // Total score
            VStack {
                Text("TOTAL SCORE")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(String(format: "%.1f", gameState.totalScore))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.yellow)
            }

            // Medal check
            if let medal = getMedal() {
                HStack {
                    Image(systemName: "medal.fill")
                        .foregroundColor(medal.color)
                    Text(medal.name)
                        .font(.headline)
                        .foregroundColor(medal.color)
                }
            }

            HStack(spacing: 20) {
                Button(action: onRestart) {
                    Text("Jump Again")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onBack) {
                    Text("Back to Menu")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .padding()
    }

    func styleColor(for score: Float) -> Color {
        if score >= 18.5 { return .green }
        if score >= 17.0 { return .yellow }
        if score >= 15.0 { return .orange }
        return .red
    }

    func getMedal() -> (name: String, color: Color)? {
        let score = gameState.totalScore
        switch hill {
        case .normalHill:
            if score >= 130 { return ("GOLD", .yellow) }
            if score >= 120 { return ("SILVER", .gray) }
            if score >= 110 { return ("BRONZE", .orange) }
        case .largeHill:
            if score >= 140 { return ("GOLD", .yellow) }
            if score >= 130 { return ("SILVER", .gray) }
            if score >= 120 { return ("BRONZE", .orange) }
        case .skiFlying:
            if score >= 200 { return ("GOLD", .yellow) }
            if score >= 180 { return ("SILVER", .gray) }
            if score >= 160 { return ("BRONZE", .orange) }
        }
        return nil
    }
}
