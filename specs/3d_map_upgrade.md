# Specification: 3D Map Upgrade (Behemoth)

- **Status**: Draft / Planning
- **Target**: Regatta Pro (Mac/iOS) - Regatta Live Section
- **Core Tech**: SceneKit (SCNView), Custom Metal Shaders

## 1. Vision
A premium, high-performance 3D visualization of the race course. This view acts as a **pure visual wrapper** on top of the live race state feed, providing a "SailGP-style" broadcast experience.

## 2. 3D Environment & Assets

### Sea State (Optimized)
- **Surface**: Custom shader-based water plane (`SCNShaderModifier`).
- **Texture**: Tiled seamless water texture with wind-driven wave animations.
- **Optimization**: No real-time ray tracing; environment-mapped reflections only. High interpolation quality for smooth visuals.

### J70 3D Boat Model
- **Components**: Hull, Mast, Sails (Main, Jib, Jennaker), Keel.
- **Dynamic Identification**: 
    - Hull and sails match **Boat Color** from telemetry.
    - **Boat Number** rendered on the bow and sail.
    - Floating **Team Name Tag** billboarded above the mast.
- **Sailing Modes**:
    - **Upwind**: Sails tight, boat heeled (leeward) based on IMU Roll.
    - **Downwind**: Asymmetric spinnaker (Jennaker) deployed when wind angle > 90°.
    - **Maneuvers**: Procedural animations for tacks and gybes.

### Course Marks & Boundaries
- **Standard Assets**: Cylindrical, Spherical, and Spar buoys.
- **MarkSetBot**: Specialized 3D model with dual-pontoon base and orange/yellow inflatable canopy.
- **Course Border (The Sponsor Wall)**: 
    - A translucent, 3D hanging curtain (2-4m tall) along the course boundary.
    - Supports dynamic logo projection/texturing for sponsors.
- **Rules Mapping**: 2/3 boat length zones visualized as semi-transparent disks on the water.

## 3. Technical Architecture

### Pure Visual Wrapper Topology
- **Dumb Rendering**: The 3D engine does not calculate state. It strictly subscribes to `RaceStateModel` transforms.
- **Dashboard Integration**: Modular view component compatible with the drag-and-drop live control center.

### Configuration & Settings
- **Sponsor Management**: Dedicated settings panel to manage logos and border visibility.
- **Dynamic Texturing**: Real-time application of logo assets to the 3D curtain geometry.

### Camera & Tracking
- **Drone View**: follow-cam tracking target boat or lead group.
- **Broadcast Node**: Fixed view from the Committee Boat (Starboard end of start line) looking down the course.
- **Auto-Switching**: Intelligent camera transitions based on race events (e.g., focus on the start during the countdown).

### Data Pipeline
- **Sync**: Subscribes to `RaceEngineClient` telemetry.
- **Smoothness**: Linear/Dead-reckoning interpolation to ensure fluid motion even at 1Hz updates.

## 4. Implementation Phasing
1. **Foundation**: Base `SCNScene` with shader-driven water and coordinate mapping.
2. **Assets**: Import J70, MarkSetBot models, and construct the Course Border Wall.
3. **Dynamics**: Link boat heel/sails to telemetry and wind state.
4. **Settings**: Implement the Sponsor Management UI and dynamic wall texturing.
5. **Cameras**: Implement Drone and Broadcast tracking logic.
6. **HUD & Polish**: Add boat ID overlays and visual effects (wakes/spray).
