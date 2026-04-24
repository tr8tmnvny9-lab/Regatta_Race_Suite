import SwiftUI
import MapKit
import CoreLocation

// Representable Wrapper for MKMapView specifically for the Broadcast View
struct BroadcastTacticalMap: NSViewRepresentable {
    @EnvironmentObject var raceState: RaceStateModel
    @EnvironmentObject var mapInteraction: MapInteractionModel
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Use a dark, muted map style for broadcast contrast
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        
        // Add OpenSeaMap Maritime Overlay
        let seaMapOverlay = MaritimeTileOverlay()
        mapView.addOverlay(seaMapOverlay, level: .aboveLabels)
        
        // Add Dynamic Tactical Overlay (all-in-one drawing for performance)
        let tacticalOverlay = DynamicTacticalOverlay()
        mapView.addOverlay(tacticalOverlay, level: .aboveRoads)
        
        // Enable interaction in Live View
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // PERFORMANCE: Bypass updates if not in broadcast/live mode
        guard raceState.isBroadcastModeActive else { return }
        
        // Sync Annotations via Coordinator to avoid locking the UI thread
        context.coordinator.updateAnnotations(on: mapView, realBoats: raceState.boats, courseMarks: raceState.course.marks)
        
        // Sync Overlays (Boundaries, Zones, Lines)
        updateOverlays(on: mapView)
        
        // Ensure user can interact (pan/zoom) in Live View as requested
        if !mapView.isScrollEnabled {
            mapView.isScrollEnabled = true
            mapView.isZoomEnabled = true
            mapView.isPitchEnabled = true
            mapView.isRotateEnabled = true
        }

        // Handle explicit region requests for Live Map (independent of Designer)
        if let liveRegion = mapInteraction.liveMapRegion {
            context.coordinator.isProgrammaticChange = true
            mapView.setRegion(liveRegion, animated: true)
            DispatchQueue.main.async {
                mapInteraction.liveMapRegion = nil
            }
            return
        }

        // Broadcast Auto-Framing: Only if auto-tracking is enabled
        if mapInteraction.isLiveMapAutoTracking {
            var top = -90.0, bottom = 90.0, left = 180.0, right = -180.0
            var hasAction = false
            
            for boat in raceState.boats {
                top = max(top, boat.pos.lat)
                bottom = min(bottom, boat.pos.lat)
                left = min(left, boat.pos.lon)
                right = max(right, boat.pos.lon)
                hasAction = true
            }
            
            for mark in raceState.course.marks {
                top = max(top, mark.pos.lat)
                bottom = min(bottom, mark.pos.lat)
                left = min(left, mark.pos.lon)
                right = max(right, mark.pos.lon)
                hasAction = true
            }
            
            if hasAction {
                let centerLat = (top + bottom) / 2
                let centerLon = (left + right) / 2
                let spanLat = max((top - bottom) * 1.5, 0.01)
                let spanLon = max((right - left) * 1.5, 0.01)
                
                let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                                                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon))
                
                // Only set if the change is significant or it's the first frame
                if mapView.region.center.latitude == 0 || abs(mapView.region.center.latitude - centerLat) > 0.001 {
                    context.coordinator.isProgrammaticChange = true
                    mapView.setRegion(region, animated: true)
                }
            }
        }
    }
    
    
    private func updateOverlays(on mapView: MKMapView) {
        let hasTactical = mapView.overlays.contains { $0 is DynamicTacticalOverlay }
        if !hasTactical {
            let tacticalOverlay = DynamicTacticalOverlay()
            mapView.addOverlay(tacticalOverlay, level: .aboveLabels)
        }
        
        if let tacticalOverlay = mapView.overlays.first(where: { $0 is DynamicTacticalOverlay }),
           let renderer = mapView.renderer(for: tacticalOverlay) as? DynamicTacticalRenderer {
            renderer.setNeedsDisplay()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // --- Coordinator ---
    class Coordinator: NSObject, MKMapViewDelegate, TacticalProvider {
        var parent: BroadcastTacticalMap
        
        var raceState: RaceStateModel { parent.raceState }
        var mapInteraction: MapInteractionModel { parent.mapInteraction }
        
        init(_ parent: BroadcastTacticalMap) {
            self.parent = parent
        }
        
        var isProgrammaticChange = false
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // If the change wasn't triggered by our auto-director/explicit request, it's manual
            if !isProgrammaticChange {
                DispatchQueue.main.async {
                    if self.parent.mapInteraction.isLiveMapAutoTracking {
                        self.parent.mapInteraction.isLiveMapAutoTracking = false
                    }
                    self.parent.mapInteraction.liveMapRegion = mapView.region
                }
            }
            
            // Reset flag after any change (programmatic or manual)
            isProgrammaticChange = false
        }
        
        func updateAnnotations(on mapView: MKMapView, realBoats: [LiveBoat], courseMarks: [Buoy]) {
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
            
            // Update Buoys
            for buoy in courseMarks {
                keepBuoyIds.insert(buoy.id)
                if let existing = existingBuoys[buoy.id] {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.2
                        existing.coordinate = buoy.pos.coordinate
                    }
                } else {
                    toAdd.append(BuoyAnnotation(buoy: buoy))
                }
            }
            
            // Update Boats explicitly with Real Telemetry Data
            for boat in realBoats {
                keepBoatIds.insert(boat.id)
                if let existing = existingBoats[boat.id] {
                    // Update coordinate natively to animate
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.5 // Standard sync rate
                        existing.coordinate = boat.pos.coordinate
                    }
                } else {
                    toAdd.append(BoatAnnotation(boat: boat))
                }
            }
            
            for b in existingBuoys.values { if !keepBuoyIds.contains(b.buoyId) { toRemove.append(b) } }
            for b in existingBoats.values { if !keepBoatIds.contains(b.boatId) { toRemove.append(b) } }
            
            mapView.removeAnnotations(toRemove)
            mapView.addAnnotations(toAdd)
        }
        
        func rendererFor(_ mapView: MKMapView, overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            
            if let tacticalOverlay = overlay as? DynamicTacticalOverlay {
                return DynamicTacticalRenderer(overlay: tacticalOverlay, provider: self)
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Note: Individual polygon rendering removed in favor of DynamicTacticalOverlay
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let buoyAnn = annotation as? BuoyAnnotation {
                let identifier = "BuoyAnnBroadcast"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                guard let buoy = parent.raceState.course.marks.first(where: { $0.id == buoyAnn.buoyId }) else { return view }
                
                let swiftUIView = BuoySymbolView(buoyId: buoy.id)
                    .environmentObject(parent.raceState)
                    .environmentObject(parent.mapInteraction)
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                view?.centerOffset = CGPoint(x: 0, y: -20)
                return view
            }
            
            if let boatAnn = annotation as? BoatAnnotation {
                let identifier = "BoatAnnBroadcast"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                guard let boat = parent.raceState.boats.first(where: { $0.id == boatAnn.boatId }) else { return view }
                
                let swiftUIView = BoatSymbolView(role: boat.role, heading: boat.heading, twd: parent.raceState.twd, color: Color(name: boat.color ?? "Blue"))
                
                let hostingView = NSHostingView(rootView: swiftUIView)
                hostingView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                
                view?.subviews.forEach { $0.removeFromSuperview() }
                view?.addSubview(hostingView)
                view?.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }
            return nil
        }
    }
}
