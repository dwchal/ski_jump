# Olympic Ski Jump

A first-person ski jump game for macOS using native Apple frameworks (SceneKit, SwiftUI).

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ or Swift 5.9+

## Building & Running

```bash
swift build
swift run OlympicSkiJump
```

Or open in Xcode:
```bash
open Package.swift
```

## Gameplay

Experience the thrill of Olympic ski jumping from a first-person perspective. Compete on three different hills with increasing difficulty.

### Hills

| Hill | K-Point | Hill Size | Difficulty |
|------|---------|-----------|------------|
| Normal Hill | K-90 | HS-100 | Beginner |
| Large Hill | K-120 | HS-140 | Intermediate |
| Ski Flying | K-185 | HS-225 | Expert |

### Controls

| Key | Action |
|-----|--------|
| SPACE | Start descent / Jump off ramp / Prepare landing |
| W | Lean forward (better aerodynamics) |
| S | Lean backward |
| A | Balance left |
| D | Balance right |
| ESC | Return to menu |

### Scoring

- **Distance Points**: Based on how far you jump relative to the K-point
- **Style Points**: 5 judges score your form (takeoff timing, flight stability, landing)
- **Wind Compensation**: Adjusted based on wind conditions
- **Telemark Landing**: Bonus for proper landing technique (prepare with SPACE before touchdown)

### Tips

1. Time your jump (SPACE) right at the edge of the takeoff ramp
2. Lean forward (W) during flight for better lift
3. Keep your balance steady - avoid excessive left/right movement
4. Press SPACE before landing to prepare for telemark

## Features

- Realistic ski jump physics
- First-person immersive view
- Three Olympic-standard hills
- Dynamic wind conditions
- Full scoring system with style judges
- Medal awards (Gold, Silver, Bronze)

## Screenshots

Launch the game to experience:
- Snow-covered mountains
- Stadium crowds
- Distance markers
- Real-time speed display
- Wind indicator
