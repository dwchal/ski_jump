import SwiftUI

struct MainMenuView: View {
    @State private var selectedHill: SkiHill = .normalHill
    @State private var isPlaying = false
    @State private var showInstructions = false

    var body: some View {
        ZStack {
            // Background gradient - winter sky
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.6, blue: 0.9),
                    Color(red: 0.7, green: 0.85, blue: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Snow mountains background
            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.6))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.2, y: geometry.size.height * 0.3))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.35, y: geometry.size.height * 0.5))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.25))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.7, y: geometry.size.height * 0.45))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.85, y: geometry.size.height * 0.2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.4))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.9))
            }

            if isPlaying {
                GameView(hill: selectedHill, onBack: { isPlaying = false })
                    .transition(.opacity)
            } else {
                VStack(spacing: 30) {
                    // Olympic rings
                    HStack(spacing: 8) {
                        Circle().stroke(Color.blue, lineWidth: 4).frame(width: 30, height: 30)
                        Circle().stroke(Color.black, lineWidth: 4).frame(width: 30, height: 30)
                        Circle().stroke(Color.red, lineWidth: 4).frame(width: 30, height: 30)
                        Circle().stroke(Color.yellow, lineWidth: 4).frame(width: 30, height: 30)
                        Circle().stroke(Color.green, lineWidth: 4).frame(width: 30, height: 30)
                    }
                    .padding(.top, 40)

                    Text("OLYMPIC SKI JUMP")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)

                    Text("First Person Experience")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // Hill selection
                    VStack(spacing: 15) {
                        Text("SELECT HILL")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(SkiHill.allCases, id: \.self) { hill in
                            HillSelectionButton(
                                hill: hill,
                                isSelected: selectedHill == hill,
                                action: { selectedHill = hill }
                            )
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 40)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)

                    Spacer()

                    // Start button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlaying = true
                        }
                    }) {
                        Text("START COMPETITION")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)

                    Button(action: { showInstructions = true }) {
                        Text("How to Play")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
    }
}

struct HillSelectionButton: View {
    let hill: SkiHill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hill.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(hill.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("K-\(hill.kPoint)")
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                    Text(hill.difficulty)
                        .font(.caption)
                        .foregroundColor(hill.difficultyColor)
                }
            }
            .padding()
            .frame(maxWidth: 400)
            .background(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("HOW TO PLAY")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 15) {
                InstructionRow(key: "SPACE", description: "Start descent / Jump off the ramp")
                InstructionRow(key: "W / S", description: "Lean forward / backward (affects aerodynamics)")
                InstructionRow(key: "A / D", description: "Balance left / right")
                InstructionRow(key: "SPACE (in air)", description: "Prepare for landing")
                InstructionRow(key: "ESC", description: "Return to menu")
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("SCORING")
                    .font(.headline)

                Text("Distance Points: Based on how far you jump past the K-point")
                Text("Style Points: 5 judges score your form (max 20 each)")
                Text("Landing: Telemark landing gives bonus points!")
            }
            .padding()

            Button("Got it!") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(width: 500, height: 450)
        .padding()
    }
}

struct InstructionRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(5)
                .frame(width: 150, alignment: .center)

            Text(description)
                .foregroundColor(.secondary)
        }
    }
}
