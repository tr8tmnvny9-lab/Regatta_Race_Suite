# Specification: 3D Map Upgrade (Behemoth)

- **Status**: Draft / Planning
- **Target**: Regatta Pro (Mac/iOS) - Regatta Live Section
- **Core Tech**: SceneKit (SCNView), Metal Shaders

## 1. Vision
A premium, high-performance 3D visualization of the race course, inspired by SailGP live broadcasts. This view is an alternative visualization mode **exclusively within the Regatta Live section**, ensuring the core Tactical and Designer views remain optimized.

## 2. 3D Environment

### Sea State
- **Surface**: Custom shader-based water plane. Semi-transparent teal/blue with subtle wind-influenced waves.
- **Rules Visualization**: 
    - **2/3 Boat Length Zones**: Persistent semi-transparent disks on the water around each mark.
    - **Active Rule Cones**: Visual highlighting when a boat enters a mark zone.

### J70 3D Boat Model
- **Components**: Hull (team color), Mast, Keel, Sails (Main, Jib, Jennaker).
- **Sailing Modes (Visual States)**:
    - **Upwind**: Sails tight, boat heeled (leeward).
    - **Reaching**: Sails eased, boat flat.
    - **Downwind**: Asymmetric spinnaker (Jennaker) deployed.
    - **Maneuvers**: Procedural animations for tacks and gybes.

## 3. Technical Architecture

### Frontend (Swift / SceneKit)
- **ThreeDMapView**: `SCNView` wrapper for SwiftUI.
- **Node System**:
    - `BoatNode`: Subclass of `SCNNode` with state-driven sail/heel logic.
    - `BuoyNode`: 3D models for different mark types (Cylindrical, Spar, etc.).
- **Camera**: Dynamic follow-cam with user override (orbit/zoom).
- **HUD Layer**: AR-style overlays for Speed, VMG, and Rank using SpriteKit or SwiftUI.

### Data & Performance
- **Data Flow**: Subscribes to `RaceStateModel` (via `RaceEngineClient`).
- **Interpolation**: Linear/Dead-reckoning for smooth movement at lower telemetry rates.
- **Optimization**: Low-poly assets, static batching of course elements, and LOD for distant boats.

## 4. Implementation Phasing
1. **Foundation**: Base `SCNScene` with water and coordinate mapping.
2. **Assets**: Import J70 model and course marks.
3. **Dynamics**: Link boat rotation/heel to TWD and boat state.
4. **Rules**: Add the 2/3 boat length zones and entry highlights.
5. **Polishing**: Visual effects (wakes, spray) and SailGP-style HUD.
