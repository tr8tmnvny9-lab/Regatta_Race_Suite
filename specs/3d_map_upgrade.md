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

### Course Marks (Buoys)
- **Standard Assets**: Cylindrical, Spherical, and Spar buoys.
- **MarkSetBot**: Specialized 3D model with dual-pontoon base, orange/yellow inflatable canopy, and central antenna.
- **Rules Mapping**: 2/3 boat length zones visualized as semi-transparent disks on the water.

## 3. Technical Architecture

### Pure Visual Wrapper Topology
- **Dumb Rendering**: The 3D engine does not calculate state, rules, or core physics. It strictly subscribes to the `RaceStateModel` feed.
- **Dashboard Integration**: Modular view component designed for the drag-and-drop live dashboard (alongside 2D map, cameras, etc.).

### Camera & Tracking Systems
- **Drone View**: Intelligent follow-cam tracking lead boats or selected targets with smooth damping.
- **Broadcast Node**: Fixed view from the Committee Boat (Starboard end of start line) looking down the course/start area.
- **Auto-Switching**: Context-aware camera transitions (e.g., focus on the start during the sequence).

### Data & Performance
- **Sync**: Direct mapping of `RaceStateModel` properties (LatLon, Heading, Roll, Speed).
- **Smoothness**: Linear/Dead-reckoning interpolation to handle 1Hz-10Hz telemetry updates.
- **Performance**: Low-poly assets and shader optimizations targeting 60FPS on M-series Macs.

## 4. Implementation Phasing
1. **Foundation**: Base `SCNScene` with shader-driven water and coordinate mapping.
2. **Assets**: Integration of J70 and MarkSetBot models.
3. **Dynamics**: Linking boat heel/sails to IMU data and wind state.
4. **Cameras**: Implementation of Drone and Broadcast tracking logic.
5. **HUD & Wrap**: Final SailGP-style overlays and drag-and-drop UI integration.
