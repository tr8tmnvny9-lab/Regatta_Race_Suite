import SwiftUI
import MapKit
import QuartzCore

// Custom models for Annotations are now in TacticalRenderingLib.swift

// Representable Wrapper for MKMapView
struct NativeTacticalMap: NSViewRepresentable {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var raceEngine: RaceEngineClient
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    // An optional closure to handle map click events
    var onMapClick: ((CLLocationCoordinate2D) -> Void)?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Use a dark, muted map style to make the colorful maritime layer pop
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        
        // Add OpenSeaMap Maritime Overlay
        let seaMapOverlay = MaritimeTileOverlay()
        mapView.addOverlay(seaMapOverlay, level: .aboveLabels)
        
        // Add Dynamic Tactical Overlay (all-in-one drawing for performance)
        let tacticalOverlay = DynamicTacticalOverlay()
        mapView.addOverlay(tacticalOverlay, level: .aboveRoads)
        
        // Handle Clicks - Ensure it doesn't delay drag initiation
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapClick(_:)))
        clickGesture.delaysPrimaryMouseButtonEvents = false
        mapView.addGestureRecognizer(clickGesture)
        
        // CUSTOM PAN GESTURE - For instant "Object on Canvas" dragging
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        panGesture.delegate = context.coordinator // Add delegate to allow selective claiming
        mapView.addGestureRecognizer(panGesture)
        
        // Disable rotation and pitch to keep a pure tactical top-down view
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Sync Annotations
        updateAnnotations(on: mapView)
        
        // Sync Overlays (Boundaries, Zones, Lines)
        updateOverlays(on: mapView)
        
        // Sync Camera if instructed explicitly
        if let region = mapInteraction.explicitMapRegion {
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                mapInteraction.explicitMapRegion = nil
                mapInteraction.lastAppliedCourseRegion = region
            }
        } else if let lastRegion = mapInteraction.lastAppliedCourseRegion, mapView.region.center.latitude == 0 {
            // Apply last known region on first load if not explicitly set
            mapView.setRegion(lastRegion, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // --- Data Sync Logic ---
    private func updateAnnotations(on mapView: MKMapView) {
        let isDragging = mapInteraction.draggingMarkId != nil
        let dragId = mapInteraction.draggingMarkId
        
        var existingBuoys = [String: BuoyAnnotation]()
        var existingBoats = [String: BoatAnnotation]()
        
        for annotation in mapView.annotations {
            if let b = annotation as? BuoyAnnotation { existingBuoys[b.buoyId] = b }
            if let b = annotation as? BoatAnnotation { existingBoats[b.boatId] = b }
        }
        
        var toAdd: [MKAnnotation] = []
        var toRemove: [MKAnnotation] = []
        var keepBuoyIds = Set<String>()
        var keepBoatIds = Set<String>()
        
        // 1. Update Buoys
        for buoy in raceState.course.marks {
            keepBuoyIds.insert(buoy.id)
            if let existing = existingBuoys[buoy.id] {
                // If this is the mark being dragged, we skip state-driven coordinate updates
                // to prevent MapKit from fighting with our direct view-frame updates.
                if isDragging && buoy.id == dragId { continue }
                
                // Update coordinate natively to animate (smoothly tracks slow movements)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    existing.coordinate = buoy.pos.coordinate
                }
            } else {
                toAdd.append(BuoyAnnotation(buoy: buoy))
            }
        }
        
        // 2. Update Boats
        for boat in raceState.boats {
            keepBoatIds.insert(boat.id)
            if let existing = existingBoats[boat.id] {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    existing.coordinate = boat.pos.coordinate
                }
            } else {
                toAdd.append(BoatAnnotation(boat: boat))
            }
        }
        
        // 3. Cleanup
        for b in existingBuoys.values { if !keepBuoyIds.contains(b.buoyId) { toRemove.append(b) } }
        for b in existingBoats.values { if !keepBoatIds.contains(b.boatId) { toRemove.append(b) } }
        
        mapView.removeAnnotations(toRemove)
        mapView.addAnnotations(toAdd)
    }
    
    private func updateOverlays(on mapView: MKMapView) {
        // We no longer add/remove hundreds of polylines.
        // We just ensure the DynamicTacticalOverlay is present and trigger its renderer.
        
        let hasTactical = mapView.overlays.contains { $0 is DynamicTacticalOverlay }
        if !hasTactical {
            let tacticalOverlay = DynamicTacticalOverlay()
            mapView.addOverlay(tacticalOverlay, level: .aboveLabels)
        }
        
        // Trigger redraw on the dynamic overlay with a fresh Main-Thread snapshot
        if let tacticalOverlay = mapView.overlays.first(where: { $0 is DynamicTacticalOverlay }) {
            if let renderer = mapView.renderer(for: tacticalOverlay) as? DynamicTacticalRenderer {
                // Generate Snapshot (Main Thread)
                let snapshot = TacticalSnapshot(
                    marks: raceState.course.marks,
                    boats: raceState.boats,
                    courseBoundary: raceState.course.courseBoundary,
                    restrictionZones: raceState.course.restrictionZones,
                    twd: raceState.twd,
                    tws: raceState.tws,
                    showMarkZones: mapInteraction.showMarkZones,
                    markZoneMultiplier: mapInteraction.markZoneMultiplier,
                    showHeightToMark: mapInteraction.showHeightToMark
                )
                
                renderer.snapshot = snapshot
                renderer.dragMarkId = mapInteraction.draggingMarkId
                renderer.dragCoordinate = mapInteraction.draggingCoordinate
                renderer.setNeedsDisplay()
            }
        }
    }
    
    // Mathematical helpers and classes moved to TacticalRenderingLib.swift
    
    
    // --- Coordinator ---
    class Coordinator: NSObject, MKMapViewDelegate, NSGestureRecognizerDelegate, TacticalProvider {
        var parent: NativeTacticalMap
        
        var raceState: RaceStateModel { parent.raceState }
        var mapInteraction: MapInteractionModel { parent.mapInteraction }
        
        init(_ parent: NativeTacticalMap) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Save current region to model to survive tab switching
            // Triggers only when animation/drag stops, eliminating the MapKit Main-Thread flood loop
            DispatchQueue.main.async {
                self.parent.mapInteraction.lastAppliedCourseRegion = mapView.region
            }
        }
        
        @objc func handleMapClick(_ gesture: NSClickGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            
            // Hit test for buoy annotations
            let annotations = mapView.annotations(in: mapView.visibleMapRect)
            var clickedBuoy: BuoyAnnotation?
            for ann in annotations {
                if let buoyAnn = ann as? BuoyAnnotation {
                    let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                    let dist = hypot(annPoint.x - point.x, annPoint.y - point.y)
                    if dist < 40 { clickedBuoy = buoyAnn; break }
                }
            }
            
            if let buoy = clickedBuoy {
                let buoyId = buoy.buoyId
                // --- DUAL SELECTION SYNC ---
                var idsToSelect = Set<String>([buoyId])
                if let b = parent.raceState.course.marks.first(where: { $0.id == buoyId }) {
                    let isSibling: (Buoy) -> Bool = { other in
                        if other.id == b.id { return false }
                        if other.type != b.type { return false }
                        
                        let suffixes = [" P", " S", " Pin", " Boat", " (Port)", " (Starboard)"]
                        var cleanA = b.name
                        var cleanB = other.name
                        for s in suffixes {
                            if cleanA.hasSuffix(s) { cleanA = String(cleanA.dropLast(s.count)) }
                            if cleanB.hasSuffix(s) { cleanB = String(cleanB.dropLast(s.count)) }
                        }
                        return cleanA == cleanB
                    }
                    if let sibling = parent.raceState.course.marks.first(where: isSibling) {
                        idsToSelect.insert(sibling.id)
                    }
                }
                parent.mapInteraction.selectedBuoyIds = idsToSelect
                parent.mapInteraction.selectedBuoyId = buoyId
            } else {
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                parent.onMapClick?(coordinate)
            }
        }
        
        // Selective Gesture Claiming: Only begin if we are over a mark
        func gestureRecognizerShouldBegin(_ gesture: NSGestureRecognizer) -> Bool {
            guard let pan = gesture as? NSPanGestureRecognizer, let mapView = pan.view as? MKMapView else { return true }
            let point = pan.location(in: mapView)
            
            // Fast hit test for buoy annotations
            let annotations = mapView.annotations(in: mapView.visibleMapRect)
            for ann in annotations {
                if let buoyAnn = ann as? BuoyAnnotation {
                    let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                    let dist = hypot(annPoint.x - point.x, annPoint.y - point.y)
                    if dist < 40 { return true } // Claim the gesture
                }
            }
            return false // Allow map to pan
        }
        
        @objc func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            
            switch gesture.state {
            case .began:
                // Hit test for a buoy annotation view
                // We check a small area around the point for annotations
                let hitRect = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
                let _ = mapView.convert(hitRect, toRegionFrom: mapView)
                
                // Find nearest buoy annotation
                let annotations = mapView.annotations(in: mapView.visibleMapRect)
                var bestBuoy: BuoyAnnotation?
                var minDist = Double.greatestFiniteMagnitude
                
                for ann in annotations {
                    if let buoyAnn = ann as? BuoyAnnotation {
                        let annPoint = mapView.convert(buoyAnn.coordinate, toPointTo: mapView)
                        let dist = hypot(annPoint.x - point.x, annPoint.y - point.y)
                        if dist < 50 && dist < minDist {
                            minDist = dist
                            bestBuoy = buoyAnn
                        }
                    }
                }
                
                if let buoy = bestBuoy {
                    let buoyId = buoy.buoyId
                    parent.mapInteraction.draggingMarkId = buoyId
                    parent.mapInteraction.draggingCoordinate = buoy.coordinate
                    
                    // --- DUAL SELECTION SYNC ---
                    var idsToSelect = Set<String>([buoyId])
                    if let b = parent.raceState.course.marks.first(where: { $0.id == buoyId }) {
                        let isSibling: (Buoy) -> Bool = { other in
                            if other.id == b.id { return false }
                            if other.type != b.type { return false }
                            
                            let suffixes = [" P", " S", " Pin", " Boat", " (Port)", " (Starboard)"]
                            var cleanA = b.name
                            var cleanB = other.name
                            for s in suffixes {
                                if cleanA.hasSuffix(s) { cleanA = String(cleanA.dropLast(s.count)) }
                                if cleanB.hasSuffix(s) { cleanB = String(cleanB.dropLast(s.count)) }
                            }
                            return cleanA == cleanB
                        }
                        if let sibling = parent.raceState.course.marks.first(where: isSibling) {
                            idsToSelect.insert(sibling.id)
                        }
                    }
                    
                    parent.mapInteraction.selectedBuoyIds = idsToSelect
                    parent.mapInteraction.selectedBuoyId = buoyId
                }
                
            case .changed:
                if let markId = parent.mapInteraction.draggingMarkId {
                    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                    
                    // 1. Move the annotation view DIRECTLY for zero lag
                    if let annotation = mapView.annotations.first(where: { ($0 as? BuoyAnnotation)?.buoyId == markId }) as? BuoyAnnotation {
                        // Updating the coordinate directly is very fast in MapKit
                        // as it doesn't trigger a full re-render of the map tiles.
                        annotation.coordinate = coordinate
                    }
                    
                    // 2. Clear state updates to avoid SwiftUI overhead
                    // We only store it in the renderer's local vars
                    if let tacticalOverlay = mapView.overlays.first(where: { $0 is DynamicTacticalOverlay }),
                       let renderer = mapView.renderer(for: tacticalOverlay) as? DynamicTacticalRenderer {
                        renderer.dragMarkId = markId
                        renderer.dragCoordinate = coordinate
                        
                        // Force instantaneous redraw on the GPU
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        renderer.setNeedsDisplay()
                        CATransaction.commit()
                    }
                }
                
            case .ended, .cancelled:
                if let dragId = parent.mapInteraction.draggingMarkId {
                    // Update state with final coord
                    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                    
                    // Commit to engine/state
                    if let idx = parent.raceState.course.marks.firstIndex(where: { $0.id == dragId }) {
                        parent.raceState.course.marks[idx].pos = LatLon(lat: coordinate.latitude, lon: coordinate.longitude)
                        parent.raceEngine.updateBuoyConfig(buoy: parent.raceState.course.marks[idx])
                    }
                    
                    // Clear direct drag refs
                    if let tacticalOverlay = mapView.overlays.first(where: { $0 is DynamicTacticalOverlay }),
                       let renderer = mapView.renderer(for: tacticalOverlay) as? DynamicTacticalRenderer {
                        renderer.dragMarkId = nil
                        renderer.dragCoordinate = nil
                        renderer.setNeedsDisplay()
                    }
                    
                    parent.mapInteraction.draggingMarkId = nil
                    parent.mapInteraction.draggingCoordinate = nil
                    parent.mapInteraction.selectedBuoyId = dragId
                }
                
            default: break
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            
            if let tacticalOverlay = overlay as? DynamicTacticalOverlay {
                return DynamicTacticalRenderer(overlay: tacticalOverlay, provider: self)
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // --- Dragging Support ---
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            
            guard let buoyAnn = view.annotation as? BuoyAnnotation else { return }
            
            if newState == .starting {
                parent.mapInteraction.draggingMarkId = buoyAnn.buoyId
            }
            
            if newState == .dragging {
                parent.mapInteraction.draggingCoordinate = buoyAnn.coordinate
                
                // Force an overlay refresh for real-time line rendering
                // Since updateNSView might not trigger fast enough, we can nudge the map view
                parent.updateOverlays(on: mapView)
            }
            
            if newState == .ending {
                let finalCoord = buoyAnn.coordinate
                parent.mapInteraction.draggingCoordinate = nil
                parent.mapInteraction.draggingMarkId = nil
                
                if let idx = parent.raceState.course.marks.firstIndex(where: { $0.id == buoyAnn.buoyId }) {
                    parent.raceState.course.marks[idx].pos = LatLon(lat: finalCoord.latitude, lon: finalCoord.longitude)
                    parent.raceEngine.updateBuoyConfig(buoy: parent.raceState.course.marks[idx])
                }
                view.setDragState(.none, animated: true)
            }
            
            if newState == .canceling {
                parent.mapInteraction.draggingCoordinate = nil
                parent.mapInteraction.draggingMarkId = nil
                view.setDragState(.none, animated: true)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // We'll wrap SwiftUI views inside NSHostingView within the MKAnnotationView for seamless integration
            if let buoyAnn = annotation as? BuoyAnnotation {
                let identifier = "BuoyAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    view?.isDraggable = false // Disable native dragging; using custom pan gesture
                    
                    // Match visual frame; hit testing is now in the PanGesture
                    view?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                }
                
                guard let buoy = parent.raceState.course.marks.first(where: { $0.id == buoyAnn.buoyId }) else { return view }
                
                let swiftUIView = BuoySymbolView(buoyId: buoy.id)
                    .environmentObject(parent.raceState)
                    .environmentObject(parent.mapInteraction)
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = view?.bounds ?? .zero
                
                // Clear out old subviews
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                
                // Important: Anchor to center. 
                view?.centerOffset = .zero
                
                return view
            }
            
            if let boatAnn = annotation as? BoatAnnotation {
                let identifier = "BoatAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                guard let boat = parent.raceState.boats.first(where: { $0.id == boatAnn.boatId }) else { return view }
                
                let swiftUIView = BoatSymbolView(role: boat.role, heading: boat.heading, twd: parent.raceState.twd, color: Color(name: boat.color ?? "Blue"))
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                view?.centerOffset = CGPoint(x: 0, y: 0) // Center
                
                return view
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let buoyAnn = view.annotation as? BuoyAnnotation {
                parent.mapInteraction.selectedBuoyId = buoyAnn.buoyId
            }
            if let boatAnn = view.annotation as? BoatAnnotation {
                parent.mapInteraction.selectedBoatId = boatAnn.boatId
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if let buoyAnn = view.annotation as? BuoyAnnotation, parent.mapInteraction.selectedBuoyId == buoyAnn.buoyId {
                parent.mapInteraction.selectedBuoyId = nil
            }
            if let boatAnn = view.annotation as? BoatAnnotation, parent.mapInteraction.selectedBoatId == boatAnn.boatId {
                parent.mapInteraction.selectedBoatId = nil
            }
        }
    }
}

// Note: All rendering and math helpers have been moved to TacticalRenderingLib.swift
