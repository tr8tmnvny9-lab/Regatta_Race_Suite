import React, { useEffect, useState } from 'react';
import { Marker, Popup, Polyline, Polygon, TileLayer, useMapEvents, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import { Trash2 } from 'lucide-react';
import { FleetHeatmapLayer } from './MapLayers';

const BOAT_ICON = (heading: number) => L.divIcon({
    className: 'boat-marker',
    html: `
        <div style="transform: rotate(${heading}deg); transition: transform 0.5s ease; filter: drop-shadow(0 0 5px rgba(6,182,212,0.5));">
            <svg width="24" height="40" viewBox="0 0 24 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2C12 2 4 12 4 24C4 32.8366 7.58172 38 12 38C16.4183 38 20 32.8366 20 24C20 12 12 2 12 2Z" fill="#06B6D4" fill-opacity="0.8" stroke="white" stroke-width="2"/>
                <path d="M12 6V20" stroke="white" stroke-width="2" stroke-linecap="round"/>
            </svg>
        </div>
    `,
    iconSize: [24, 40],
    iconAnchor: [12, 38] // Anchored near the stern/pivot point
});

const calculateDeadReckoning = (pos: { lat: number, lon: number }, speedKts: number, headingDeg: number, timeSec: number) => {
    // 1 knot = 0.514444 m/s
    const speedMps = speedKts * 0.514444;
    const distanceMeters = speedMps * timeSec;

    // Earth radius in meters
    const R = 6378137;
    const brng = headingDeg * Math.PI / 180;
    const lat1 = pos.lat * Math.PI / 180;
    const lon1 = pos.lon * Math.PI / 180;

    const lat2 = Math.asin(Math.sin(lat1) * Math.cos(distanceMeters / R) +
        Math.cos(lat1) * Math.sin(distanceMeters / R) * Math.cos(brng));
    const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(distanceMeters / R) * Math.cos(lat1),
        Math.cos(distanceMeters / R) - Math.sin(lat1) * Math.sin(lat2));

    return { lat: lat2 * 180 / Math.PI, lon: lon2 * 180 / Math.PI };
};

const GHOST_ICON = (heading: number) => L.divIcon({
    className: 'boat-marker-ghost',
    html: `
        <div style="transform: rotate(${heading}deg); transition: transform 0.5s ease; opacity: 0.4;">
            <svg width="24" height="40" viewBox="0 0 24 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2C12 2 4 12 4 24C4 32.8366 7.58172 38 12 38C16.4183 38 20 32.8366 20 24C20 12 12 2 12 2Z" fill="#9ca3af" fill-opacity="0.2" stroke="#9ca3af" stroke-width="2" stroke-dasharray="2 2"/>
                <path d="M12 6V20" stroke="#9ca3af" stroke-width="1" stroke-linecap="round" stroke-dasharray="2 2"/>
            </svg>
        </div>
    `,
    iconSize: [24, 40],
    iconAnchor: [12, 38]
});


interface TacticalMapProps {
    raceState: any;
    activeTab: string;
    selectedTool: string | null;
    drawingMode: boolean;
    zoom: number;
    autoOrient: boolean;
    showHeatmap: boolean;
    syncDrag: boolean;
    measurePoints?: { lat: number, lon: number }[];
    setMeasurePoints?: React.Dispatch<React.SetStateAction<{ lat: number, lon: number }[]>>;
    draggingMarkId: React.MutableRefObject<string | null>;
    playbackTime?: number | null;
    socket: any;
    setRaceState: React.Dispatch<React.SetStateAction<any>>;
    renderBuoyIcon: (mark: any, size: number, autoOrient: boolean) => L.DivIcon;
    LaylineLayer: React.FC<any>;
    CourseBoundaryDrawing: React.FC<any>;
    onUpdateBoundary: (b: { lat: number, lon: number }[] | null) => void;
    onDeleteMark?: (id: string) => void;
}

const TacticalMap = ({
    raceState,
    activeTab,
    selectedTool,
    drawingMode,
    zoom,
    autoOrient,
    showHeatmap,
    syncDrag,
    measurePoints,
    draggingMarkId,
    playbackTime,
    socket,
    setRaceState,
    renderBuoyIcon,
    LaylineLayer,
    CourseBoundaryDrawing,
    onUpdateBoundary,
    onDeleteMark
}: TacticalMapProps) => {
    const map = useMapEvents({
        moveend: () => {
            if (activeTab === 'DESIGNER' || activeTab === 'OVERVIEW') {
                const center = map.getCenter();
                const currentZoom = map.getZoom();
                socket?.emit('update-default-location', { lat: center.lat, lon: center.lng, zoom: currentZoom });
            }
        }
    });
    const [localMarks, setLocalMarks] = useState(raceState.course.marks);
    const dragOrigin = React.useRef<{ lat: number, lon: number } | null>(null);

    const activeBoats = React.useMemo(() => {
        if (!playbackTime || !raceState.fleetHistory) return raceState.boats;
        const historicalBoats: Record<string, any> = {};
        for (const [boatId, history] of Object.entries(raceState.fleetHistory as Record<string, any[]>)) {
            if (!history || history.length === 0) continue;
            let closest = history[0];
            let minDiff = Infinity;
            for (const ping of history) {
                const diff = Math.abs(ping.timestamp - playbackTime);
                if (diff < minDiff) {
                    minDiff = diff;
                    closest = ping;
                }
            }
            if (minDiff < 30000) { // Only show if we have data within 30 seconds of scrubber
                historicalBoats[boatId] = {
                    ...raceState.boats[boatId],
                    pos: { lat: closest.lat, lon: closest.lon },
                    dtl: 0,
                    velocity: { speed: 0, dir: 0 }
                };
            }
        }
        return historicalBoats;
    }, [raceState.boats, raceState.fleetHistory, playbackTime]);

    // Sync localMarks with raceState when not dragging
    useEffect(() => {
        if (!draggingMarkId.current) {
            setLocalMarks(raceState.course.marks);
        }
    }, [raceState.course.marks]);

    // Fit course to screen on autoOrient or boundary change
    useEffect(() => {
        if (!map || !raceState.course.courseBoundary || raceState.course.courseBoundary.length < 3) return;

        const bounds = L.latLngBounds(raceState.course.courseBoundary.map((p: any) => [p.lat, p.lon]));
        map.fitBounds(bounds, { padding: [100, 100], animate: true });
    }, [autoOrient, raceState.course.courseBoundary, map]);

    const size = Math.max(8, Math.min(48, (zoom - 10) * 8));

    const formatMeasurement = (p1: any, p2: any) => {
        const R = 3440.065; // Earth radius in nautical miles
        const lat1 = p1.lat * Math.PI / 180;
        const lat2 = p2.lat * Math.PI / 180;
        const dLat = (p2.lat - p1.lat) * Math.PI / 180;
        const dLon = (p2.lon - p1.lon) * Math.PI / 180;

        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1) * Math.cos(lat2) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c;

        const y = Math.sin(dLon) * Math.cos(lat2);
        const x = Math.cos(lat1) * Math.sin(lat2) -
            Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
        const brng = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;

        return `${distance.toFixed(2)} NM | ${Math.round(brng)}°`;
    };

    return (
        <>
            <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            />

            {raceState.course.courseBoundary && (
                <Polygon
                    positions={raceState.course.courseBoundary.map((p: any) => [p.lat, p.lon])}
                    pathOptions={{ color: '#06b6d4', weight: 2, fillOpacity: 0.05, dashArray: '10, 10' }}
                />
            )}

            {/* Only render laylines when not dragging for performance */}
            {!draggingMarkId.current && (
                <LaylineLayer marks={localMarks} windDir={raceState.wind.direction} boundary={raceState.course.courseBoundary} />
            )}

            <CourseBoundaryDrawing isDrawing={drawingMode} boundary={raceState.course.courseBoundary} setBoundary={onUpdateBoundary} />

            {/* Gate lines are also expensive, hide them during drag to stay at 60fps */}
            {!draggingMarkId.current && (
                localMarks.filter((m: any) => m.type === 'GATE' && m.pairId).reduce((acc: any[], current: any) => {
                    if (!acc.find(g => g.pairId === current.pairId)) {
                        const pairMember = localMarks.find((m: any) => m.pairId === current.pairId && m.id !== current.id);
                        if (pairMember) acc.push({ pairId: current.pairId, p1: current.pos, p2: pairMember.pos });
                    }
                    return acc;
                }, []).map((gate: any) => (
                    <Polyline
                        key={`gate-line-${gate.pairId}`}
                        positions={[[gate.p1.lat, gate.p1.lon], [gate.p2.lat, gate.p2.lon]]}
                        pathOptions={{ color: '#06b6d4', weight: 2, dashArray: '5, 10', opacity: 0.5 }}
                    />
                ))
            )}

            {/* Start/Finish lines - hide during drag */}
            {!draggingMarkId.current && (
                <>
                    {localMarks.filter((m: any) => m.type === 'START' && m.pairId).reduce((acc: any[], current: any) => {
                        if (!acc.find(g => g.pairId === current.pairId)) {
                            const pairMember = localMarks.find((m: any) => m.pairId === current.pairId && m.id !== current.id);
                            if (pairMember) acc.push({ pairId: current.pairId, p1: current.pos, p2: pairMember.pos });
                        }
                        return acc;
                    }, []).map((line: any) => (
                        <Polyline
                            key={`start-line-${line.pairId}`}
                            positions={[[line.p1.lat, line.p1.lon], [line.p2.lat, line.p2.lon]]}
                            pathOptions={{ color: '#fbbf24', weight: 4, dashArray: '10, 10' }}
                        />
                    ))}
                    {localMarks.filter((m: any) => m.type === 'FINISH' && m.pairId).reduce((acc: any[], current: any) => {
                        if (!acc.find(g => g.pairId === current.pairId)) {
                            const pairMember = localMarks.find((m: any) => m.pairId === current.pairId && m.id !== current.id);
                            if (pairMember) acc.push({ pairId: current.pairId, p1: current.pos, p2: pairMember.pos });
                        }
                        return acc;
                    }, []).map((line: any) => (
                        <Polyline
                            key={`finish-line-${line.pairId}`}
                            positions={[[line.p1.lat, line.p1.lon], [line.p2.lat, line.p2.lon]]}
                            pathOptions={{ color: '#3b82f6', weight: 4, dashArray: '10, 10' }}
                        />
                    ))}
                </>
            )}

            {/* Measurement Tool */}
            {measurePoints && measurePoints.length > 0 && (
                <>
                    {measurePoints.map((p, i) => (
                        <Marker
                            key={`m-pt-${i}`}
                            position={[p.lat, p.lon]}
                            icon={L.divIcon({ className: 'custom-measure-point', html: '<div style="width: 8px; height: 8px; background: white; border: 1px solid black; border-radius: 50%;"></div>', iconSize: [8, 8], iconAnchor: [4, 4] })}
                        />
                    ))}
                    {measurePoints.length === 2 && (
                        <Polyline positions={[[measurePoints[0].lat, measurePoints[0].lon], [measurePoints[1].lat, measurePoints[1].lon]]} pathOptions={{ color: 'white', weight: 2, dashArray: '5, 5' }}>
                            <Tooltip permanent direction="center" className="bg-black/90 text-white border border-white/20 text-[11px] font-mono px-3 py-1.5 rounded-lg shadow-xl shadow-black/50" opacity={1}>
                                {formatMeasurement(measurePoints[0], measurePoints[1])}
                            </Tooltip>
                        </Polyline>
                    )}
                </>
            )}

            {localMarks.map((mark: any) => (
                <Marker
                    key={mark.id}
                    position={[mark.pos.lat, mark.pos.lon]}
                    draggable={activeTab === 'DESIGNER' && !selectedTool}
                    eventHandlers={{
                        dragstart: () => {
                            draggingMarkId.current = mark.id;
                            dragOrigin.current = { lat: mark.pos.lat, lon: mark.pos.lon };
                        },
                        drag: (e) => {
                            // Using direct Leaflet manipulation (Vector-fast)
                            // We don't call setLocalMarks here to avoid React re-render lag
                            const marker = e.target;
                            marker.setLatLng(marker.getLatLng());
                        },
                        dragend: (e) => {
                            const marker = e.target;
                            const position = marker.getLatLng();

                            let deltaLat = 0;
                            let deltaLon = 0;
                            if (dragOrigin.current) {
                                deltaLat = position.lat - dragOrigin.current.lat;
                                deltaLon = position.lng - dragOrigin.current.lon;
                            }

                            const updatedMarks = localMarks.map((m: any) => {
                                if (m.id === mark.id) {
                                    return { ...m, pos: { lat: position.lat, lon: position.lng } };
                                }
                                // Linked translation for pair
                                if (syncDrag && mark.pairId && m.pairId === mark.pairId && m.id !== mark.id) {
                                    return { ...m, pos: { lat: m.pos.lat + deltaLat, lon: m.pos.lon + deltaLon } };
                                }
                                return m;
                            });

                            const updatedCourse = { ...raceState.course, marks: updatedMarks };

                            // Force sync back to React state on end
                            setLocalMarks(updatedMarks);
                            setRaceState((prev: any) => ({ ...prev, course: updatedCourse }));
                            socket?.emit('update-course', updatedCourse);

                            setTimeout(() => {
                                draggingMarkId.current = null;
                                dragOrigin.current = null;
                            }, 50);
                        },
                        click: (e) => {
                            // Explicitly open popup on click to ensure reliability
                            e.target.openPopup();
                        }
                    }}
                    icon={renderBuoyIcon(mark, size, autoOrient)}
                >
                    <Popup className={`glass-popup ${autoOrient ? 'unrotate-popup' : ''}`}>
                        <div className="bg-regatta-panel p-4 rounded-xl flex flex-col gap-3 min-w-[240px] text-white">
                            <div className="flex flex-col gap-2">
                                <input
                                    type="text"
                                    value={mark.name}
                                    onChange={(e) => {
                                        const updated = localMarks.map((m: any) => m.id === mark.id ? { ...m, name: e.target.value } : m);
                                        socket?.emit('update-course', { ...raceState.course, marks: updated });
                                    }}
                                    className="bg-black/40 border border-white/10 rounded px-2 py-1 text-xs font-bold uppercase tracking-widest text-accent-blue outline-none"
                                />
                                <label className="flex items-center gap-2 cursor-pointer group/toggle mt-1">
                                    <span className="text-[9px] font-black text-gray-500 uppercase tracking-widest group-hover/toggle:text-gray-300 transition-colors">Show Laylines</span>
                                    <input
                                        type="checkbox"
                                        checked={!mark.disableLaylines}
                                        onChange={(e) => {
                                            const updated = localMarks.map((m: any) => m.id === mark.id ? { ...m, disableLaylines: !e.target.checked } : m);
                                            socket?.emit('update-course', { ...raceState.course, marks: updated });
                                        }}
                                        className="w-3.5 h-3.5 rounded bg-black/40 border border-white/10 checked:bg-accent-blue transition-all"
                                    />
                                </label>
                                <div className="flex gap-1 justify-center py-1 mt-1">
                                    {['yellow', 'orange', 'red', 'green', 'blue'].map(c => (
                                        <div
                                            key={c}
                                            onClick={() => {
                                                const updated = localMarks.map((m: any) =>
                                                    (m.id === mark.id || (mark.pairId && m.pairId === mark.pairId))
                                                        ? { ...m, color: c } : m
                                                );
                                                socket?.emit('update-course', { ...raceState.course, marks: updated });
                                            }}
                                            className={`w-6 h-6 rounded-full cursor-pointer border-2 transition-transform hover:scale-110 ${mark.color === c ? 'border-white' : 'border-black/50'}`}
                                            style={{ backgroundColor: c === 'yellow' ? '#fbbf24' : c === 'orange' ? '#f97316' : c === 'red' ? '#ef4444' : c === 'green' ? '#22c55e' : '#3b82f6' }}
                                        />
                                    ))}
                                </div>
                            </div>

                            <div className="flex flex-col gap-2 border-t border-white/10 pt-2">
                                <span className="text-[9px] font-black uppercase text-gray-500 tracking-[0.2em]">Mark Design</span>
                                <div className="grid grid-cols-2 gap-2">
                                    {['BUOY', 'TUBE', 'POLE', 'MARKSETBOT'].map((d) => (
                                        <button
                                            key={d}
                                            onClick={() => {
                                                const updated = localMarks.map((m: any) =>
                                                    (m.id === mark.id || (mark.pairId && m.pairId === mark.pairId))
                                                        ? { ...m, design: d as any } : m
                                                );
                                                socket?.emit('update-course', { ...raceState.course, marks: updated });
                                            }}
                                            className={`py-1.5 text-[8px] font-bold uppercase border rounded transition-all ${mark.design === d ? 'bg-accent-blue border-accent-blue text-white shadow-glow-blue' : 'border-white/10 text-gray-400 hover:text-white hover:bg-white/5'}`}
                                        >
                                            {d}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {(mark.type === 'GATE' || mark.type === 'MARK' || mark.type === 'START' || mark.type === 'FINISH') && (
                                <div className="flex flex-col gap-2 pt-2 border-t border-white/10">
                                    <span className="text-[9px] font-black uppercase text-gray-500 tracking-[0.2em]">Layline Orientation</span>
                                    <div className="flex gap-2">
                                        <button
                                            onClick={() => {
                                                const updated = localMarks.map((m: any) => (m.id === mark.id || (mark.pairId && m.pairId === mark.pairId)) ? { ...m, gateDirection: 'UPWIND' } : m);
                                                socket?.emit('update-course', { ...raceState.course, marks: updated });
                                            }}
                                            className={`flex-1 py-1.5 text-[9px] font-bold uppercase border rounded transition-all ${mark.gateDirection === 'UPWIND' ? 'bg-accent-blue border-accent-blue text-white shadow-glow-blue' : 'border-white/10 text-gray-500'}`}
                                        >
                                            Upwind
                                        </button>
                                        <button
                                            onClick={() => {
                                                const updated = localMarks.map((m: any) => (m.id === mark.id || (mark.pairId && m.pairId === mark.pairId)) ? { ...m, gateDirection: 'DOWNWIND' } : m);
                                                socket?.emit('update-course', { ...raceState.course, marks: updated });
                                            }}
                                            className={`flex-1 py-1.5 text-[9px] font-black uppercase border rounded transition-all ${mark.gateDirection === 'DOWNWIND' ? 'bg-accent-blue border-accent-blue text-white shadow-glow-blue' : 'border-white/10 text-gray-500'}`}
                                        >
                                            Downwind
                                        </button>
                                    </div>
                                </div>
                            )}

                            <div className="flex gap-2 pt-2 border-t border-white/10">
                                <button
                                    onClick={() => {
                                        const updated = localMarks.map((m: any) => m.id === mark.id ? { ...m, rounding: 'PORT' } : m);
                                        socket?.emit('update-course', { ...raceState.course, marks: updated });
                                    }}
                                    className={`flex-1 py-1.5 text-[9px] font-bold uppercase border rounded ${mark.rounding === 'PORT' ? 'bg-accent-red text-white border-accent-red' : 'border-white/10 text-gray-400'}`}
                                >
                                    Port
                                </button>
                                <button
                                    onClick={() => {
                                        const updated = localMarks.map((m: any) => m.id === mark.id ? { ...m, rounding: 'STARBOARD' } : m);
                                        socket?.emit('update-course', { ...raceState.course, marks: updated });
                                    }}
                                    className={`flex-1 py-1.5 text-[9px] font-bold uppercase border rounded ${mark.rounding === 'STARBOARD' ? 'bg-accent-green text-white border-accent-green' : 'border-white/10 text-gray-400'}`}
                                >
                                    Stbd
                                </button>
                            </div>

                            <button
                                onClick={() => onDeleteMark?.(mark.id)}
                                className="flex items-center justify-center gap-2 text-accent-red text-[10px] font-bold uppercase hover:bg-accent-red/10 py-2 rounded-lg transition-colors border border-accent-red/20 mt-2"
                            >
                                <Trash2 size={12} /> Remove Mark
                            </button>
                        </div>
                    </Popup>
                </Marker>
            ))}

            {/* Fleet */}
            <FleetHeatmapLayer boats={activeBoats} visible={showHeatmap} />
            {Object.entries(activeBoats).map(([id, boat]: [string, any]) => {
                const isMoving = boat.velocity && boat.velocity.speed > 0.5;
                const drPos = isMoving ? calculateDeadReckoning(boat.pos, boat.velocity.speed, boat.imu?.heading || 0, 15) : null;

                return (
                    <React.Fragment key={`boat-group-${id}`}>
                        <Marker
                            position={[boat.pos.lat, boat.pos.lon]}
                            icon={BOAT_ICON(boat.imu?.heading || 0)}
                        />
                        {drPos && !playbackTime && (
                            <>
                                <Polyline
                                    positions={[[boat.pos.lat, boat.pos.lon], [drPos.lat, drPos.lon]]}
                                    pathOptions={{ color: '#9ca3af', weight: 1, dashArray: '4, 4', opacity: 0.5 }}
                                />
                                <Marker
                                    position={[drPos.lat, drPos.lon]}
                                    icon={GHOST_ICON(boat.imu?.heading || 0)}
                                    interactive={false}
                                />
                            </>
                        )}
                    </React.Fragment>
                );
            })}
        </>
    );
};

export default React.memo(TacticalMap);
