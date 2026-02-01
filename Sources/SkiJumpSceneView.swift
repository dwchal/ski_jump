import SwiftUI
import SceneKit
import AppKit

struct SkiJumpSceneView: NSViewRepresentable {
    let hill: SkiHill
    @ObservedObject var gameState: GameState

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false

        // Set up keyboard handling
        context.coordinator.setupKeyboardHandling(for: scnView)

        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.updateGameState(gameState)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hill: hill, gameState: gameState)
    }

    class Coordinator: NSObject {
        let scene: SCNScene
        let hill: SkiHill
        var gameState: GameState

        // Scene nodes
        var cameraNode: SCNNode!
        var skierNode: SCNNode!
        var skiTips: SCNNode!

        // Physics - use CGFloat for SceneKit compatibility
        var velocityX: CGFloat = 0
        var velocityY: CGFloat = 0
        var velocityZ: CGFloat = 0
        var positionX: CGFloat = 0
        var positionY: CGFloat = 0
        var positionZ: CGFloat = 0
        var isOnGround = true
        var jumpStartZ: CGFloat = 0
        var takeoffEdgeZ: CGFloat = 0

        // Animation
        var displayLink: CVDisplayLink?
        var lastUpdateTime: TimeInterval = 0

        // Input state
        var keysPressed: Set<UInt16> = []

        init(hill: SkiHill, gameState: GameState) {
            self.hill = hill
            self.gameState = gameState
            self.scene = SCNScene()

            super.init()

            setupScene()
            setupCamera()
            setupSkier()
            resetPosition()
            startGameLoop()
        }

        deinit {
            stopGameLoop()
        }

        func updateGameState(_ newState: GameState) {
            self.gameState = newState
            if newState.phase == .ready {
                resetPosition()
            }
        }

        func setupScene() {
            // Ambient light
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.intensity = 500
            ambientLight.light!.color = NSColor(white: 0.8, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)

            // Directional light (sun)
            let sunLight = SCNNode()
            sunLight.light = SCNLight()
            sunLight.light!.type = .directional
            sunLight.light!.intensity = 1000
            sunLight.light!.castsShadow = true
            sunLight.light!.shadowMode = .deferred
            sunLight.light!.shadowColor = NSColor(white: 0, alpha: 0.5)
            sunLight.position = SCNVector3(50, 100, -50)
            sunLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(sunLight)

            // Build the ski jump
            buildSkiJump()
            buildEnvironment()
        }

        func buildSkiJump() {
            let inrunLength = CGFloat(hill.inrunLength)
            let inrunAngle = CGFloat(hill.inrunAngle) * .pi / 180
            let takeoffAngle = CGFloat(hill.takeoffAngle) * .pi / 180
            let landingAngle = CGFloat(hill.landingHillAngle) * .pi / 180

            // Calculate positions
            let startHeight = inrunLength * sin(inrunAngle)
            let startZ = -inrunLength * cos(inrunAngle)

            // Inrun track
            let inrunGeometry = SCNBox(width: 3, height: 0.3, length: inrunLength + 10, chamferRadius: 0)
            let inrunMaterial = SCNMaterial()
            inrunMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
            inrunMaterial.roughness.contents = 0.3
            inrunGeometry.materials = [inrunMaterial]

            let inrunNode = SCNNode(geometry: inrunGeometry)
            inrunNode.position = SCNVector3(0, startHeight / 2 - 0.15, startZ / 2)
            inrunNode.eulerAngles.x = -inrunAngle
            scene.rootNode.addChildNode(inrunNode)

            // Track rails
            for xOffset: CGFloat in [-1.2, 1.2] {
                let railGeometry = SCNBox(width: 0.1, height: 0.15, length: inrunLength + 10, chamferRadius: 0)
                let railMaterial = SCNMaterial()
                railMaterial.diffuse.contents = NSColor.red
                railGeometry.materials = [railMaterial]

                let railNode = SCNNode(geometry: railGeometry)
                railNode.position = SCNVector3(xOffset, startHeight / 2, startZ / 2)
                railNode.eulerAngles.x = -inrunAngle
                scene.rootNode.addChildNode(railNode)
            }

            // Takeoff table
            let tableLength: CGFloat = 8.0
            takeoffEdgeZ = tableLength * cos(takeoffAngle)

            let tableGeometry = SCNBox(width: 3, height: 0.3, length: tableLength, chamferRadius: 0)
            let tableMaterial = SCNMaterial()
            tableMaterial.diffuse.contents = NSColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
            tableGeometry.materials = [tableMaterial]

            let tableNode = SCNNode(geometry: tableGeometry)
            tableNode.position = SCNVector3(0, tableLength * sin(takeoffAngle) / 2 - 0.15, tableLength * cos(takeoffAngle) / 2)
            tableNode.eulerAngles.x = takeoffAngle
            scene.rootNode.addChildNode(tableNode)

            // Landing hill
            let landingLength = CGFloat(hill.hillSize) * 1.5
            let landingStartZ = takeoffEdgeZ + 5
            let landingEndZ = landingStartZ + landingLength * cos(landingAngle)
            let landingDropY = landingLength * sin(landingAngle)

            let landingGeometry = SCNBox(width: 40, height: 0.5, length: landingLength, chamferRadius: 0)
            let landingMaterial = SCNMaterial()
            landingMaterial.diffuse.contents = NSColor.white
            landingMaterial.roughness.contents = 0.1
            landingGeometry.materials = [landingMaterial]

            let landingNode = SCNNode(geometry: landingGeometry)
            landingNode.position = SCNVector3(0, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) / 2)
            landingNode.eulerAngles.x = landingAngle
            scene.rootNode.addChildNode(landingNode)

            // K-point marker
            let kPointZ = landingStartZ + CGFloat(hill.kPoint) * cos(landingAngle) * 0.8
            let kPointY = -CGFloat(hill.kPoint) * sin(landingAngle) * 0.8 - 5

            let kPointMarker = SCNNode(geometry: SCNBox(width: 1, height: 0.1, length: 5, chamferRadius: 0))
            kPointMarker.geometry?.firstMaterial?.diffuse.contents = NSColor.red
            kPointMarker.position = SCNVector3(0, kPointY + 0.3, kPointZ)
            kPointMarker.eulerAngles.x = landingAngle
            scene.rootNode.addChildNode(kPointMarker)

            // Distance markers every 10m
            for distance in stride(from: 50, through: hill.hillSize + 20, by: 10) {
                let distanceCG = CGFloat(distance)
                let markerZ = landingStartZ + distanceCG * cos(landingAngle) * 0.8
                let markerY = -distanceCG * sin(landingAngle) * 0.8 - 5

                let markerGeometry = SCNBox(width: 0.5, height: 0.05, length: 2, chamferRadius: 0)
                let markerMaterial = SCNMaterial()
                markerMaterial.diffuse.contents = distance == hill.kPoint ? NSColor.red : NSColor.blue
                markerGeometry.materials = [markerMaterial]

                let marker = SCNNode(geometry: markerGeometry)
                marker.position = SCNVector3(-18, markerY + 0.3, markerZ)
                marker.eulerAngles.x = landingAngle
                scene.rootNode.addChildNode(marker)

                // Distance text
                let textGeometry = SCNText(string: "\(distance)m", extrusionDepth: 0.1)
                textGeometry.font = NSFont.systemFont(ofSize: 2)
                textGeometry.firstMaterial?.diffuse.contents = NSColor.black

                let textNode = SCNNode(geometry: textGeometry)
                textNode.position = SCNVector3(-22, markerY + 0.5, markerZ)
                textNode.scale = SCNVector3(0.5, 0.5, 0.5)
                scene.rootNode.addChildNode(textNode)
            }

            // Outrun (flat area after landing)
            let outrunGeometry = SCNBox(width: 40, height: 0.5, length: 100, chamferRadius: 0)
            outrunGeometry.firstMaterial?.diffuse.contents = NSColor.white
            let outrunNode = SCNNode(geometry: outrunGeometry)
            outrunNode.position = SCNVector3(0, -landingDropY - 6, landingEndZ + 50)
            scene.rootNode.addChildNode(outrunNode)

            // Stadium structures
            buildStadium(at: SCNVector3(-25, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) * 0.4))
            buildStadium(at: SCNVector3(25, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) * 0.4))
        }

        func buildStadium(at position: SCNVector3) {
            // Simple bleacher structure
            let bleacherGeometry = SCNBox(width: 15, height: 8, length: 60, chamferRadius: 0)
            let bleacherMaterial = SCNMaterial()
            bleacherMaterial.diffuse.contents = NSColor.gray
            bleacherGeometry.materials = [bleacherMaterial]

            let bleacher = SCNNode(geometry: bleacherGeometry)
            bleacher.position = position
            scene.rootNode.addChildNode(bleacher)

            // Crowd (colored dots)
            for _ in 0..<50 {
                let personGeometry = SCNSphere(radius: 0.3)
                let colors: [NSColor] = [.red, .blue, .yellow, .green, .orange, .purple]
                personGeometry.firstMaterial?.diffuse.contents = colors.randomElement()

                let person = SCNNode(geometry: personGeometry)
                person.position = SCNVector3(
                    position.x + CGFloat.random(in: -6...6),
                    position.y + 4.5,
                    position.z + CGFloat.random(in: -28...28)
                )
                scene.rootNode.addChildNode(person)
            }
        }

        func buildEnvironment() {
            // Sky dome
            let skyGeometry = SCNSphere(radius: 500)
            let skyMaterial = SCNMaterial()
            skyMaterial.diffuse.contents = NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
            skyMaterial.isDoubleSided = true
            skyGeometry.materials = [skyMaterial]

            let skyNode = SCNNode(geometry: skyGeometry)
            scene.rootNode.addChildNode(skyNode)

            // Surrounding mountains
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let distance: CGFloat = 200
                let mountainGeometry = SCNCone(topRadius: 0, bottomRadius: CGFloat.random(in: 40...80), height: CGFloat.random(in: 60...120))
                let mountainMaterial = SCNMaterial()
                mountainMaterial.diffuse.contents = NSColor.white
                mountainGeometry.materials = [mountainMaterial]

                let mountain = SCNNode(geometry: mountainGeometry)
                mountain.position = SCNVector3(
                    distance * cos(angle),
                    CGFloat.random(in: -20...10),
                    distance * sin(angle)
                )
                scene.rootNode.addChildNode(mountain)
            }

            // Pine trees on sides
            for _ in 0..<30 {
                let treeX = CGFloat.random(in: -100 ... -30)
                let treeZ = CGFloat.random(in: -50...150)
                createTree(at: SCNVector3(treeX, getGroundHeight(at: treeX, z: treeZ), treeZ))

                let treeX2 = CGFloat.random(in: 30...100)
                createTree(at: SCNVector3(treeX2, getGroundHeight(at: treeX2, z: treeZ), treeZ))
            }

            // Ground plane
            let groundGeometry = SCNPlane(width: 600, height: 600)
            let groundMaterial = SCNMaterial()
            groundMaterial.diffuse.contents = NSColor.white
            groundGeometry.materials = [groundMaterial]

            let groundNode = SCNNode(geometry: groundGeometry)
            groundNode.eulerAngles.x = -.pi / 2
            groundNode.position = SCNVector3(0, -50, 100)
            scene.rootNode.addChildNode(groundNode)
        }

        func getGroundHeight(at x: CGFloat, z: CGFloat) -> CGFloat {
            return -10 + sin(x * 0.05) * 5 + sin(z * 0.03) * 3
        }

        func createTree(at position: SCNVector3) {
            let trunkGeometry = SCNCylinder(radius: 0.3, height: 3)
            trunkGeometry.firstMaterial?.diffuse.contents = NSColor.brown

            let trunk = SCNNode(geometry: trunkGeometry)
            trunk.position = position

            let foliageGeometry = SCNCone(topRadius: 0, bottomRadius: 2, height: 6)
            foliageGeometry.firstMaterial?.diffuse.contents = NSColor(red: 0.1, green: 0.4, blue: 0.1, alpha: 1.0)

            let foliage = SCNNode(geometry: foliageGeometry)
            foliage.position = SCNVector3(position.x, position.y + 4, position.z)

            scene.rootNode.addChildNode(trunk)
            scene.rootNode.addChildNode(foliage)
        }

        func setupCamera() {
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 75
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 1000

            scene.rootNode.addChildNode(cameraNode)
        }

        func setupSkier() {
            skierNode = SCNNode()

            // Ski tips visible in first person
            skiTips = SCNNode()

            // Left ski tip
            let leftSkiGeometry = SCNBox(width: 0.1, height: 0.02, length: 0.8, chamferRadius: 0.02)
            leftSkiGeometry.firstMaterial?.diffuse.contents = NSColor.orange
            let leftSki = SCNNode(geometry: leftSkiGeometry)
            leftSki.position = SCNVector3(-0.15, -0.5, 0.6)

            // Right ski tip
            let rightSkiGeometry = SCNBox(width: 0.1, height: 0.02, length: 0.8, chamferRadius: 0.02)
            rightSkiGeometry.firstMaterial?.diffuse.contents = NSColor.orange
            let rightSki = SCNNode(geometry: rightSkiGeometry)
            rightSki.position = SCNVector3(0.15, -0.5, 0.6)

            skiTips.addChildNode(leftSki)
            skiTips.addChildNode(rightSki)

            skierNode.addChildNode(skiTips)
            scene.rootNode.addChildNode(skierNode)
        }

        func resetPosition() {
            let inrunAngle = CGFloat(hill.inrunAngle) * .pi / 180
            let startHeight = CGFloat(hill.inrunLength) * sin(inrunAngle)
            let startZ = -CGFloat(hill.inrunLength) * cos(inrunAngle)

            positionX = 0
            positionY = startHeight + 1.5
            positionZ = startZ - 5
            velocityX = 0
            velocityY = 0
            velocityZ = 0
            isOnGround = true
            jumpStartZ = 0

            updateCameraPosition()
        }

        func setupKeyboardHandling(for view: SCNView) {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyDown(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                self?.handleKeyUp(event)
                return event
            }
        }

        func handleKeyDown(_ event: NSEvent) {
            keysPressed.insert(event.keyCode)

            // Space bar
            if event.keyCode == 49 {
                handleSpacePress()
            }
        }

        func handleKeyUp(_ event: NSEvent) {
            keysPressed.remove(event.keyCode)
        }

        func handleSpacePress() {
            switch gameState.phase {
            case .ready:
                startInrun()
            case .inrun:
                // Check if near takeoff edge
                if positionZ > takeoffEdgeZ - 5 {
                    initiateJump()
                }
            case .flight:
                gameState.isPreparingLanding = true
            default:
                break
            }
        }

        func startInrun() {
            DispatchQueue.main.async {
                self.gameState.phase = .inrun
                self.gameState.showMessage("GO!", duration: 1.0)
            }
        }

        func initiateJump() {
            let distanceFromEdge = abs(positionZ - takeoffEdgeZ)
            gameState.takeoffTiming = Float(min(1.0, distanceFromEdge / 5.0))

            if distanceFromEdge < 1.0 {
                DispatchQueue.main.async {
                    self.gameState.showMessage("PERFECT!", duration: 1.0)
                }
                gameState.takeoffTiming = 0
            } else if distanceFromEdge < 2.5 {
                DispatchQueue.main.async {
                    self.gameState.showMessage("GOOD!", duration: 1.0)
                }
                gameState.takeoffTiming = 0.3
            } else {
                DispatchQueue.main.async {
                    self.gameState.showMessage("LATE!", duration: 1.0)
                }
            }

            jumpStartZ = positionZ

            // Add upward velocity for jump
            let jumpBoost: CGFloat = 8.0 * CGFloat(1.0 - gameState.takeoffTiming * 0.3)
            velocityY += jumpBoost

            DispatchQueue.main.async {
                self.gameState.phase = .flight
            }
            isOnGround = false
        }

        func startGameLoop() {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                self?.updateGame()
            }
            RunLoop.main.add(timer, forMode: .common)
        }

        func stopGameLoop() {
            displayLink = nil
        }

        func updateGame() {
            let deltaTime: CGFloat = 1.0 / 60.0

            // Process input
            processInput(deltaTime: deltaTime)

            // Update physics based on game phase
            switch gameState.phase {
            case .ready:
                break

            case .inrun:
                updateInrun(deltaTime: deltaTime)

            case .takeoff:
                break

            case .flight:
                updateFlight(deltaTime: deltaTime)

            case .landing, .landed:
                updateLanding(deltaTime: deltaTime)

            case .finished:
                break
            }

            updateCameraPosition()

            // Update speed display
            let speed = sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)
            DispatchQueue.main.async {
                self.gameState.currentSpeed = Float(speed * 3.6)  // m/s to km/h
            }
        }

        func processInput(deltaTime: CGFloat) {
            let dt = Float(deltaTime)
            // W key (13) - lean forward
            if keysPressed.contains(13) {
                gameState.leanAngle = min(gameState.leanAngle + dt * 2, 1.0)
            }
            // S key (1) - lean backward
            if keysPressed.contains(1) {
                gameState.leanAngle = max(gameState.leanAngle - dt * 2, -1.0)
            }
            // A key (0) - balance left
            if keysPressed.contains(0) {
                gameState.balanceOffset = max(gameState.balanceOffset - dt * 2, -1.0)
            }
            // D key (2) - balance right
            if keysPressed.contains(2) {
                gameState.balanceOffset = min(gameState.balanceOffset + dt * 2, 1.0)
            }

            // Return to neutral if no input
            if !keysPressed.contains(13) && !keysPressed.contains(1) {
                gameState.leanAngle *= 0.95
            }
            if !keysPressed.contains(0) && !keysPressed.contains(2) {
                gameState.balanceOffset *= 0.95
            }
        }

        func updateInrun(deltaTime: CGFloat) {
            let inrunAngle = CGFloat(hill.inrunAngle) * .pi / 180
            let gravity: CGFloat = 9.81

            // Accelerate down the inrun
            let acceleration = gravity * sin(inrunAngle) * 0.95  // Some friction
            velocityZ += acceleration * deltaTime * cos(inrunAngle)
            velocityY -= acceleration * deltaTime * sin(inrunAngle) * 0.5

            // Cap speed
            let maxSpeed: CGFloat = 30.0
            let currentSpeed = sqrt(velocityZ * velocityZ + velocityY * velocityY)
            if currentSpeed > maxSpeed {
                let scale = maxSpeed / currentSpeed
                velocityZ *= scale
                velocityY *= scale
            }

            // Update position
            positionZ += velocityZ * deltaTime
            positionY += velocityY * deltaTime

            // Keep on track
            let expectedY = getTrackHeight(at: positionZ) + 1.5
            positionY = expectedY

            // Auto-jump if passed takeoff edge
            if positionZ > takeoffEdgeZ + 2 && gameState.phase == .inrun {
                initiateJump()
            }
        }

        func getTrackHeight(at z: CGFloat) -> CGFloat {
            let inrunAngle = CGFloat(hill.inrunAngle) * .pi / 180
            let takeoffAngle = CGFloat(hill.takeoffAngle) * .pi / 180
            let landingAngle = CGFloat(hill.landingHillAngle) * .pi / 180

            if z < 0 {
                // On inrun
                return -z * tan(inrunAngle)
            } else if z < takeoffEdgeZ {
                // On takeoff table
                return z * tan(takeoffAngle)
            } else {
                // On landing hill
                let landingStartZ = takeoffEdgeZ + 5
                if z > landingStartZ {
                    return -(z - landingStartZ) * tan(landingAngle) - 5
                }
                return 0
            }
        }

        func updateFlight(deltaTime: CGFloat) {
            let gravity: CGFloat = 9.81

            // Apply gravity
            velocityY -= gravity * deltaTime

            // Aerodynamic lift based on lean angle and speed
            let speed = sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)
            let liftCoefficient: CGFloat = 0.15 + CGFloat(gameState.leanAngle) * 0.08
            let lift = liftCoefficient * speed * speed * 0.001
            velocityY += lift * deltaTime * 60

            // Air resistance
            let drag: CGFloat = 0.001
            velocityX *= (1.0 - drag)
            velocityY *= (1.0 - drag * 0.5)
            velocityZ *= (1.0 - drag)

            // Wind effect
            if gameState.windDirection.contains("Head") {
                velocityZ -= CGFloat(gameState.windSpeed) * 0.1 * deltaTime
            } else if gameState.windDirection.contains("Tail") {
                velocityZ += CGFloat(gameState.windSpeed) * 0.1 * deltaTime
            }

            // Balance affects trajectory
            velocityX += CGFloat(gameState.balanceOffset) * deltaTime * 2

            // Update position
            positionX += velocityX * deltaTime
            positionY += velocityY * deltaTime
            positionZ += velocityZ * deltaTime

            // Update flight form quality based on balance
            gameState.flightFormQuality = max(0, 1.0 - abs(gameState.balanceOffset) * 0.3 - abs(gameState.leanAngle - 0.5) * 0.2)

            // Check for landing
            let groundHeight = getTrackHeight(at: positionZ)
            if positionY <= groundHeight + 1.5 {
                land()
            }

            // Calculate current distance
            let distance = positionZ - jumpStartZ
            DispatchQueue.main.async {
                self.gameState.jumpDistance = Float(distance * 1.2)  // Scale factor
            }
        }

        func land() {
            // Calculate landing quality
            let verticalSpeed = abs(velocityY)
            let horizontalBalance = abs(gameState.balanceOffset)

            if gameState.isPreparingLanding && verticalSpeed < 15 && horizontalBalance < 0.3 {
                gameState.landingQuality = 1.0
                DispatchQueue.main.async {
                    self.gameState.showMessage("TELEMARK!", duration: 1.5)
                }
            } else if verticalSpeed < 20 && horizontalBalance < 0.5 {
                gameState.landingQuality = 0.7
                DispatchQueue.main.async {
                    self.gameState.showMessage("Good Landing!", duration: 1.5)
                }
            } else {
                gameState.landingQuality = 0.4
                DispatchQueue.main.async {
                    self.gameState.showMessage("Rough Landing", duration: 1.5)
                }
            }

            DispatchQueue.main.async {
                self.gameState.phase = .landed
            }
            isOnGround = true

            // Slow down
            velocityY = 0
            velocityX *= 0.5
            velocityZ *= 0.7
        }

        func updateLanding(deltaTime: CGFloat) {
            // Decelerate on ground
            velocityX *= 0.98
            velocityZ *= 0.98

            positionX += velocityX * deltaTime
            positionZ += velocityZ * deltaTime
            positionY = getTrackHeight(at: positionZ) + 1.5

            // Stop when slow enough
            let speed = sqrt(velocityX * velocityX + velocityZ * velocityZ)
            if speed < 1.0 && gameState.phase == .landed {
                DispatchQueue.main.async {
                    self.gameState.calculateScore(for: self.hill)
                    self.gameState.phase = .finished
                }
            }
        }

        func updateCameraPosition() {
            // First person view from skier's head
            cameraNode.position = SCNVector3(positionX, positionY, positionZ)

            // Look direction based on velocity and lean
            if gameState.phase == .flight {
                // In flight, camera tilts based on lean
                let lookAngle = CGFloat(-gameState.leanAngle * 0.3)
                cameraNode.eulerAngles = SCNVector3(
                    lookAngle - 0.2,
                    CGFloat(gameState.balanceOffset) * 0.1,
                    CGFloat(gameState.balanceOffset) * 0.15
                )
            } else if gameState.phase == .inrun {
                // On inrun, look down the track
                let inrunAngle = CGFloat(hill.inrunAngle) * .pi / 180
                cameraNode.eulerAngles = SCNVector3(-inrunAngle * 0.5, 0, 0)
            } else {
                cameraNode.eulerAngles = SCNVector3(-0.1, 0, 0)
            }

            // Update ski tips position relative to camera
            skierNode.position = SCNVector3(positionX, positionY, positionZ)
            skierNode.eulerAngles = cameraNode.eulerAngles

            // Ski tips spread in V-style during flight
            if gameState.phase == .flight {
                skiTips.childNodes[0].eulerAngles.y = -0.15
                skiTips.childNodes[1].eulerAngles.y = 0.15
            } else {
                skiTips.childNodes[0].eulerAngles.y = 0
                skiTips.childNodes[1].eulerAngles.y = 0
            }
        }
    }
}
