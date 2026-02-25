import React from 'react';
import { Marker, Polyline, useMapEvents, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet.heat';
import { Buoy } from '@regatta/core';

export const CourseDesignerEvents = ({ onAddMark, selectedTool, drawingMode }: { onAddMark: (latlng: any) => void, selectedTool: string | null, drawingMode: boolean }) => {
    useMapEvents({
        click(e) {
            if (selectedTool && selectedTool !== 'BOUNDARY' && !drawingMode) {
                const originalEvent = e.originalEvent;
                const target = originalEvent.target as HTMLElement;
                if (target.closest('.leaflet-marker-icon') || target.closest('.leaflet-popup')) return;
                onAddMark(e.latlng);
            }
        },
    });
    return null;
} // Using types from App temporarily

export const WindArrowLayer = ({ boundary, windDir }: { boundary: { lat: number, lon: number }[] | null, windDir: number }) => {
    if (!boundary || boundary.length < 3) return null;

    const latSum = boundary.reduce((acc, p) => acc + p.lat, 0);
    const lonSum = boundary.reduce((acc, p) => acc + p.lon, 0);
    const center = { lat: latSum / boundary.length, lon: lonSum / boundary.length };

    const offset = 0.015;
    const rad = (windDir - 180) * Math.PI / 180;
    const arrowPos = {
        lat: center.lat - offset * Math.cos(rad),
        lon: center.lon - offset * Math.sin(rad)
    };

    return (
        <Marker
            position={[arrowPos.lat, arrowPos.lon]}
            icon={L.divIcon({
                className: 'bg-transparent',
                html: `<div style="transform: rotate(${windDir}deg); color: rgba(59, 130, 246, 0.4);">
                    <svg viewBox="0 0 24 24" width="60" height="60" fill="currentColor">
                        <path d="M12 2L4.5 20.29L5.21 21L12 18L18.79 21L19.5 20.29L12 2Z" />
                    </svg>
                </div>`,
                iconSize: [60, 60],
                iconAnchor: [30, 30]
            })}
        />
    )
}

export const LaylineLayer = ({ marks, windDir, boundary }: { marks: Buoy[], windDir: number, boundary: { lat: number, lon: number }[] | null }) => {
    if (!marks.length) return null;

    const findBoundaryIntersection = (start: { lat: number, lon: number }, bearing: number) => {
        if (!boundary || boundary.length < 3) {
            const R = 6371;
            const d = 2.0 / R;
            const lat1 = start.lat * Math.PI / 180;
            const lon1 = start.lon * Math.PI / 180;
            const brng = bearing * Math.PI / 180;
            const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng));
            const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));
            return { lat: lat2 * 180 / Math.PI, lon: lon2 * 180 / Math.PI };
        }

        const extendDist = 5.0;
        const R = 6371;
        const d = extendDist / R;
        const lat1 = start.lat * Math.PI / 180;
        const lon1 = start.lon * Math.PI / 180;
        const brng = bearing * Math.PI / 180;
        const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng));
        const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));
        const farPoint = { lat: lat2 * 180 / Math.PI, lon: lon2 * 180 / Math.PI };

        const intersect = (p1: any, p2: any, p3: any, p4: any) => {
            const den = (p4.lon - p3.lon) * (p2.lat - p1.lat) - (p4.lat - p3.lat) * (p2.lon - p1.lon);
            if (Math.abs(den) < 0.000001) return null;
            const ua = ((p4.lat - p3.lat) * (p1.lon - p3.lon) - (p4.lon - p3.lon) * (p1.lat - p3.lat)) / den;
            const ub = ((p2.lat - p1.lat) * (p1.lon - p3.lon) - (p2.lon - p1.lon) * (p1.lat - p3.lat)) / den;
            if (ua < 0 || ua > 1 || ub < 0 || ub > 1) return null;
            return { lat: p1.lat + ua * (p2.lat - p1.lat), lon: p1.lon + ua * (p2.lon - p1.lon) };
        };

        let closestDist = Infinity;
        let bestPoint = farPoint;

        for (let i = 0; i < boundary.length; i++) {
            const b1 = boundary[i];
            const b2 = boundary[(i + 1) % boundary.length];
            const intersection = intersect(start, farPoint, b1, b2);
            if (intersection) {
                const dist = Math.sqrt(Math.pow(intersection.lat - start.lat, 2) + Math.pow(intersection.lon - start.lon, 2));
                if (dist < closestDist) {
                    closestDist = dist;
                    bestPoint = intersection;
                }
            }
        }
        return bestPoint;
    };

    return (
        <>
            {marks.filter(m => (m.type === 'MARK' || m.type === 'GATE' || m.type === 'START' || m.type === 'FINISH') && !m.disableLaylines).map(m => {
                const shift = m.gateDirection === 'UPWIND' ? 180 : 0;
                const TACK_ANGLE = 45;
                const portBearing = (windDir + TACK_ANGLE + shift + 360) % 360;
                const stbdBearing = (windDir - TACK_ANGLE + shift + 360) % 360;

                const pPort = findBoundaryIntersection(m.pos, portBearing);
                const pStbd = findBoundaryIntersection(m.pos, stbdBearing);

                return (
                    <React.Fragment key={`layline-${m.id}`}>
                        <Polyline positions={[[m.pos.lat, m.pos.lon], [pPort.lat, pPort.lon]]} pathOptions={{ color: 'rgba(239,68,68,0.4)', weight: 1, dashArray: '5,5' }} />
                        <Polyline positions={[[m.pos.lat, m.pos.lon], [pStbd.lat, pStbd.lon]]} pathOptions={{ color: 'rgba(34,197,94,0.4)', weight: 1, dashArray: '5,5' }} />
                    </React.Fragment>
                )
            })}
        </>
    )
}

export const CourseBoundaryDrawing = ({
    isDrawing,
    boundary,
    setBoundary
}: {
    isDrawing: boolean,
    boundary: { lat: number, lon: number }[] | null,
    setBoundary: (b: { lat: number, lon: number }[] | null) => void
}) => {
    const map = useMapEvents({
        click(e) {
            if (!isDrawing) return;

            const newPoint = { lat: e.latlng.lat, lon: e.latlng.lng };

            if (!boundary) {
                setBoundary([newPoint]);
            } else {
                setBoundary([...boundary, newPoint]);
            }
        }
    });

    React.useEffect(() => {
        if (boundary && boundary.length > 2 && !isDrawing) {
            const bounds = L.latLngBounds(boundary.map(p => [p.lat, p.lon]));
            if (bounds.isValid()) map.flyToBounds(bounds, { padding: [50, 50], duration: 1.5 });
        }
    }, [boundary, isDrawing]);

    if (!boundary) return null;

    return (
        <>
            {boundary.length > 1 && (
                <Polyline
                    positions={boundary.map(p => [p.lat, p.lon])}
                    pathOptions={{
                        color: 'rgba(6,182,212,0.8)',
                        weight: 2,
                        dashArray: isDrawing ? '10, 10' : undefined,
                    }}
                />
            )}
        </>
    )
}

export const FleetHeatmapLayer = ({ boats, visible }: { boats: Record<string, any>, visible: boolean }) => {
    const map = useMap();
    const layerRef = React.useRef<any>(null);

    React.useEffect(() => {
        if (!visible) {
            if (layerRef.current) {
                map.removeLayer(layerRef.current);
                layerRef.current = null;
            }
            return;
        }

        const points = Object.values(boats).map(b => {
            return [b.pos?.lat || 0, b.pos?.lon || 0, 1];
        }).filter(p => p[0] !== 0 && p[1] !== 0);

        if (!layerRef.current && points.length > 0) {
            layerRef.current = (L as any).heatLayer(points, {
                radius: 35,
                blur: 25,
                maxZoom: 17,
                gradient: { 0.4: 'cyan', 0.6: 'lime', 0.8: 'yellow', 1.0: 'red' }
            }).addTo(map);
        } else if (layerRef.current) {
            layerRef.current.setLatLngs(points);
        }

    }, [boats, visible, map]);

    React.useEffect(() => {
        return () => {
            if (layerRef.current) {
                map.removeLayer(layerRef.current);
            }
        }
    }, [map]);

    return null;
}
