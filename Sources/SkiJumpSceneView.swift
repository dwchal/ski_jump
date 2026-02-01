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

        var cameraNode: SCNNode!
        var skierNode: SCNNode!
        var skiTips: SCNNode!

        // Use Float for physics, convert to CGFloat only for SceneKit
        var velX: Float = 0
        var velY: Float = 0
        var velZ: Float = 0
        var posX: Float = 0
        var posY: Float = 0
        var posZ: Float = 0
        var isOnGround = true
        var jumpStartZ: Float = 0
        var takeoffEdgeZ: Float = 0

        var displayLink: CVDisplayLink?
        var lastUpdateTime: TimeInterval = 0
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

        // Helper to create SCNVector3 from Float values
        func vec3(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
            return SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        }

        func setupScene() {
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.intensity = 500
            ambientLight.light!.color = NSColor(white: 0.8, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)

            let sunLight = SCNNode()
            sunLight.light = SCNLight()
            sunLight.light!.type = .directional
            sunLight.light!.intensity = 1000
            sunLight.light!.castsShadow = true
            sunLight.light!.shadowMode = .deferred
            sunLight.light!.shadowColor = NSColor(white: 0, alpha: 0.5)
            sunLight.position = vec3(50, 100, -50)
            sunLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(sunLight)

            buildSkiJump()
            buildEnvironment()
        }

        func buildSkiJump() {
            let inrunLength = hill.inrunLength
            let inrunAngle = hill.inrunAngle * .pi / 180
            let takeoffAngle = hill.takeoffAngle * .pi / 180
            let landingAngle = hill.landingHillAngle * .pi / 180

            let startHeight = inrunLength * sin(inrunAngle)
            let startZ = -inrunLength * cos(inrunAngle)

            // Inrun track
            let inrunGeometry = SCNBox(width: 3, height: 0.3, length: CGFloat(inrunLength + 10), chamferRadius: 0)
            let inrunMaterial = SCNMaterial()
            inrunMaterial.diffuse.contents = NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
            inrunMaterial.roughness.contents = 0.3
            inrunGeometry.materials = [inrunMaterial]

            let inrunNode = SCNNode(geometry: inrunGeometry)
            inrunNode.position = vec3(0, startHeight / 2 - 0.15, startZ / 2)
            inrunNode.eulerAngles.x = CGFloat(-inrunAngle)
            scene.rootNode.addChildNode(inrunNode)

            // Track rails
            for xOffset: Float in [-1.2, 1.2] {
                let railGeometry = SCNBox(width: 0.1, height: 0.15, length: CGFloat(inrunLength + 10), chamferRadius: 0)
                let railMaterial = SCNMaterial()
                railMaterial.diffuse.contents = NSColor.red
                railGeometry.materials = [railMaterial]

                let railNode = SCNNode(geometry: railGeometry)
                railNode.position = vec3(xOffset, startHeight / 2, startZ / 2)
                railNode.eulerAngles.x = CGFloat(-inrunAngle)
                scene.rootNode.addChildNode(railNode)
            }

            // Takeoff table
            let tableLength: Float = 8.0
            takeoffEdgeZ = tableLength * cos(takeoffAngle)

            let tableGeometry = SCNBox(width: 3, height: 0.3, length: CGFloat(tableLength), chamferRadius: 0)
            let tableMaterial = SCNMaterial()
            tableMaterial.diffuse.contents = NSColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
            tableGeometry.materials = [tableMaterial]

            let tableNode = SCNNode(geometry: tableGeometry)
            tableNode.position = vec3(0, tableLength * sin(takeoffAngle) / 2 - 0.15, tableLength * cos(takeoffAngle) / 2)
            tableNode.eulerAngles.x = CGFloat(takeoffAngle)
            scene.rootNode.addChildNode(tableNode)

            // Landing hill
            let landingLength = Float(hill.hillSize) * 1.5
            let landingStartZ = takeoffEdgeZ + 5
            let landingEndZ = landingStartZ + landingLength * cos(landingAngle)
            let landingDropY = landingLength * sin(landingAngle)

            let landingGeometry = SCNBox(width: 40, height: 0.5, length: CGFloat(landingLength), chamferRadius: 0)
            let landingMaterial = SCNMaterial()
            landingMaterial.diffuse.contents = NSColor.white
            landingMaterial.roughness.contents = 0.1
            landingGeometry.materials = [landingMaterial]

            let landingNode = SCNNode(geometry: landingGeometry)
            landingNode.position = vec3(0, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) / 2)
            landingNode.eulerAngles.x = CGFloat(landingAngle)
            scene.rootNode.addChildNode(landingNode)

            // K-point marker
            let kPointZ = landingStartZ + Float(hill.kPoint) * cos(landingAngle) * 0.8
            let kPointY = -Float(hill.kPoint) * sin(landingAngle) * 0.8 - 5

            let kPointMarker = SCNNode(geometry: SCNBox(width: 1, height: 0.1, length: 5, chamferRadius: 0))
            kPointMarker.geometry?.firstMaterial?.diffuse.contents = NSColor.red
            kPointMarker.position = vec3(0, kPointY + 0.3, kPointZ)
            kPointMarker.eulerAngles.x = CGFloat(landingAngle)
            scene.rootNode.addChildNode(kPointMarker)

            // Distance markers every 10m
            for distance in stride(from: 50, through: hill.hillSize + 20, by: 10) {
                let distF = Float(distance)
                let markerZ = landingStartZ + distF * cos(landingAngle) * 0.8
                let markerY = -distF * sin(landingAngle) * 0.8 - 5

                let markerGeometry = SCNBox(width: 0.5, height: 0.05, length: 2, chamferRadius: 0)
                let markerMaterial = SCNMaterial()
                markerMaterial.diffuse.contents = distance == hill.kPoint ? NSColor.red : NSColor.blue
                markerGeometry.materials = [markerMaterial]

                let marker = SCNNode(geometry: markerGeometry)
                marker.position = vec3(-18, markerY + 0.3, markerZ)
                marker.eulerAngles.x = CGFloat(landingAngle)
                scene.rootNode.addChildNode(marker)

                let textGeometry = SCNText(string: "\(distance)m", extrusionDepth: 0.1)
                textGeometry.font = NSFont.systemFont(ofSize: 2)
                textGeometry.firstMaterial?.diffuse.contents = NSColor.black

                let textNode = SCNNode(geometry: textGeometry)
                textNode.position = vec3(-22, markerY + 0.5, markerZ)
                textNode.scale = vec3(0.5, 0.5, 0.5)
                scene.rootNode.addChildNode(textNode)
            }

            // Outrun
            let outrunGeometry = SCNBox(width: 40, height: 0.5, length: 100, chamferRadius: 0)
            outrunGeometry.firstMaterial?.diffuse.contents = NSColor.white
            let outrunNode = SCNNode(geometry: outrunGeometry)
            outrunNode.position = vec3(0, -landingDropY - 6, landingEndZ + 50)
            scene.rootNode.addChildNode(outrunNode)

            // Stadium structures
            buildStadium(at: vec3(-25, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) * 0.4))
            buildStadium(at: vec3(25, -landingDropY / 2 - 5, landingStartZ + landingLength * cos(landingAngle) * 0.4))
        }

        func buildStadium(at position: SCNVector3) {
            let bleacherGeometry = SCNBox(width: 15, height: 8, length: 60, chamferRadius: 0)
            let bleacherMaterial = SCNMaterial()
            bleacherMaterial.diffuse.contents = NSColor.gray
            bleacherGeometry.materials = [bleacherMaterial]

            let bleacher = SCNNode(geometry: bleacherGeometry)
            bleacher.position = position
            scene.rootNode.addChildNode(bleacher)

            for _ in 0..<50 {
                let personGeometry = SCNSphere(radius: 0.3)
                let colors: [NSColor] = [.red, .blue, .yellow, .green, .orange, .purple]
                personGeometry.firstMaterial?.diffuse.contents = colors.randomElement()

                let person = SCNNode(geometry: personGeometry)
                let px = Float(position.x) + Float.random(in: -6...6)
                let py = Float(position.y) + 4.5
                let pz = Float(position.z) + Float.random(in: -28...28)
                person.position = vec3(px, py, pz)
                scene.rootNode.addChildNode(person)
            }
        }

        func buildEnvironment() {
            let skyGeometry = SCNSphere(radius: 500)
            let skyMaterial = SCNMaterial()
            skyMaterial.diffuse.contents = NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
            skyMaterial.isDoubleSided = true
            skyGeometry.materials = [skyMaterial]

            let skyNode = SCNNode(geometry: skyGeometry)
            scene.rootNode.addChildNode(skyNode)

            for i in 0..<8 {
                let angle = Float(i) * .pi / 4
                let dist: Float = 200
                let mountainGeometry = SCNCone(topRadius: 0, bottomRadius: CGFloat(Float.random(in: 40...80)), height: CGFloat(Float.random(in: 60...120)))
                let mountainMaterial = SCNMaterial()
                mountainMaterial.diffuse.contents = NSColor.white
                mountainGeometry.materials = [mountainMaterial]

                let mountain = SCNNode(geometry: mountainGeometry)
                mountain.position = vec3(dist * cos(angle), Float.random(in: -20...10), dist * sin(angle))
                scene.rootNode.addChildNode(mountain)
            }

            for _ in 0..<30 {
                let treeX = Float.random(in: -100 ... -30)
                let treeZ = Float.random(in: -50...150)
                createTree(at: vec3(treeX, getGroundHeight(at: treeX, z: treeZ), treeZ))

                let treeX2 = Float.random(in: 30...100)
                createTree(at: vec3(treeX2, getGroundHeight(at: treeX2, z: treeZ), treeZ))
            }

            let groundGeometry = SCNPlane(width: 600, height: 600)
            let groundMaterial = SCNMaterial()
            groundMaterial.diffuse.contents = NSColor.white
            groundGeometry.materials = [groundMaterial]

            let groundNode = SCNNode(geometry: groundGeometry)
            groundNode.eulerAngles.x = -.pi / 2
            groundNode.position = vec3(0, -50, 100)
            scene.rootNode.addChildNode(groundNode)
        }

        func getGroundHeight(at x: Float, z: Float) -> Float {
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
            foliage.position = vec3(Float(position.x), Float(position.y) + 4, Float(position.z))

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
            skiTips = SCNNode()

            let leftSkiGeometry = SCNBox(width: 0.1, height: 0.02, length: 0.8, chamferRadius: 0.02)
            leftSkiGeometry.firstMaterial?.diffuse.contents = NSColor.orange
            let leftSki = SCNNode(geometry: leftSkiGeometry)
            leftSki.position = vec3(-0.15, -0.5, 0.6)

            let rightSkiGeometry = SCNBox(width: 0.1, height: 0.02, length: 0.8, chamferRadius: 0.02)
            rightSkiGeometry.firstMaterial?.diffuse.contents = NSColor.orange
            let rightSki = SCNNode(geometry: rightSkiGeometry)
            rightSki.position = vec3(0.15, -0.5, 0.6)

            skiTips.addChildNode(leftSki)
            skiTips.addChildNode(rightSki)

            skierNode.addChildNode(skiTips)
            scene.rootNode.addChildNode(skierNode)
        }

        func resetPosition() {
            let inrunAngle = hill.inrunAngle * .pi / 180
            let startHeight = hill.inrunLength * sin(inrunAngle)
            let startZ = -hill.inrunLength * cos(inrunAngle)

            posX = 0
            posY = startHeight + 1.5
            posZ = startZ - 5
            velX = 0
            velY = 0
            velZ = 0
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
                if posZ > takeoffEdgeZ - 5 {
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
            let distanceFromEdge = abs(posZ - takeoffEdgeZ)
            gameState.takeoffTiming = min(1.0, distanceFromEdge / 5.0)

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

            jumpStartZ = posZ

            let jumpBoost: Float = 8.0 * (1.0 - gameState.takeoffTiming * 0.3)
            velY = velY + jumpBoost

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
            let dt: Float = 1.0 / 60.0

            processInput(dt: dt)

            switch gameState.phase {
            case .ready:
                break
            case .inrun:
                updateInrun(dt: dt)
            case .takeoff:
                break
            case .flight:
                updateFlight(dt: dt)
            case .landing, .landed:
                updateLanding(dt: dt)
            case .finished:
                break
            }

            updateCameraPosition()

            let speed = sqrt(velX * velX + velY * velY + velZ * velZ)
            DispatchQueue.main.async {
                self.gameState.currentSpeed = speed * 3.6
            }
        }

        func processInput(dt: Float) {
            if keysPressed.contains(13) {
                gameState.leanAngle = min(gameState.leanAngle + dt * 2, 1.0)
            }
            if keysPressed.contains(1) {
                gameState.leanAngle = max(gameState.leanAngle - dt * 2, -1.0)
            }
            if keysPressed.contains(0) {
                gameState.balanceOffset = max(gameState.balanceOffset - dt * 2, -1.0)
            }
            if keysPressed.contains(2) {
                gameState.balanceOffset = min(gameState.balanceOffset + dt * 2, 1.0)
            }

            if !keysPressed.contains(13) && !keysPressed.contains(1) {
                gameState.leanAngle = gameState.leanAngle * 0.95
            }
            if !keysPressed.contains(0) && !keysPressed.contains(2) {
                gameState.balanceOffset = gameState.balanceOffset * 0.95
            }
        }

        func updateInrun(dt: Float) {
            let inrunAngle = hill.inrunAngle * .pi / 180
            let gravity: Float = 9.81

            let acceleration = gravity * sin(inrunAngle) * 0.95
            velZ = velZ + acceleration * dt * cos(inrunAngle)
            velY = velY - acceleration * dt * sin(inrunAngle) * 0.5

            let maxSpeed: Float = 30.0
            let currentSpeed = sqrt(velZ * velZ + velY * velY)
            if currentSpeed > maxSpeed {
                let scale = maxSpeed / currentSpeed
                velZ = velZ * scale
                velY = velY * scale
            }

            posZ = posZ + velZ * dt
            posY = posY + velY * dt

            let expectedY = getTrackHeight(at: posZ) + 1.5
            posY = expectedY

            if posZ > takeoffEdgeZ + 2 && gameState.phase == .inrun {
                initiateJump()
            }
        }

        func getTrackHeight(at z: Float) -> Float {
            let inrunAngle = hill.inrunAngle * .pi / 180
            let takeoffAngle = hill.takeoffAngle * .pi / 180
            let landingAngle = hill.landingHillAngle * .pi / 180

            if z < 0 {
                return -z * tan(inrunAngle)
            } else if z < takeoffEdgeZ {
                return z * tan(takeoffAngle)
            } else {
                let landingStartZ = takeoffEdgeZ + 5
                if z > landingStartZ {
                    return -(z - landingStartZ) * tan(landingAngle) - 5
                }
                return 0
            }
        }

        func updateFlight(dt: Float) {
            let gravity: Float = 9.81

            velY = velY - gravity * dt

            let speed = sqrt(velX * velX + velY * velY + velZ * velZ)
            let liftCoefficient: Float = 0.15 + gameState.leanAngle * 0.08
            let lift = liftCoefficient * speed * speed * 0.001
            velY = velY + lift * dt * 60

            let drag: Float = 0.001
            velX = velX * (1.0 - drag)
            velY = velY * (1.0 - drag * 0.5)
            velZ = velZ * (1.0 - drag)

            if gameState.windDirection.contains("Head") {
                velZ = velZ - gameState.windSpeed * 0.1 * dt
            } else if gameState.windDirection.contains("Tail") {
                velZ = velZ + gameState.windSpeed * 0.1 * dt
            }

            velX = velX + gameState.balanceOffset * dt * 2

            posX = posX + velX * dt
            posY = posY + velY * dt
            posZ = posZ + velZ * dt

            gameState.flightFormQuality = max(0, 1.0 - abs(gameState.balanceOffset) * 0.3 - abs(gameState.leanAngle - 0.5) * 0.2)

            let groundHeight = getTrackHeight(at: posZ)
            if posY <= groundHeight + 1.5 {
                land()
            }

            let distance = posZ - jumpStartZ
            DispatchQueue.main.async {
                self.gameState.jumpDistance = distance * 1.2
            }
        }

        func land() {
            let verticalSpeed = abs(velY)
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

            velY = 0
            velX = velX * 0.5
            velZ = velZ * 0.7
        }

        func updateLanding(dt: Float) {
            velX = velX * 0.98
            velZ = velZ * 0.98

            posX = posX + velX * dt
            posZ = posZ + velZ * dt
            posY = getTrackHeight(at: posZ) + 1.5

            let speed = sqrt(velX * velX + velZ * velZ)
            if speed < 1.0 && gameState.phase == .landed {
                DispatchQueue.main.async {
                    self.gameState.calculateScore(for: self.hill)
                    self.gameState.phase = .finished
                }
            }
        }

        func updateCameraPosition() {
            cameraNode.position = vec3(posX, posY, posZ)

            if gameState.phase == .flight {
                let lookAngle = -gameState.leanAngle * 0.3
                cameraNode.eulerAngles = vec3(lookAngle - 0.2, gameState.balanceOffset * 0.1, gameState.balanceOffset * 0.15)
            } else if gameState.phase == .inrun {
                let inrunAngle = hill.inrunAngle * .pi / 180
                cameraNode.eulerAngles = vec3(-inrunAngle * 0.5, 0, 0)
            } else {
                cameraNode.eulerAngles = vec3(-0.1, 0, 0)
            }

            skierNode.position = vec3(posX, posY, posZ)
            skierNode.eulerAngles = cameraNode.eulerAngles

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
