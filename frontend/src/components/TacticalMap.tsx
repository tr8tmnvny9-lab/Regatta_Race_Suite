import React, { useEffect, useState } from 'react';
import { Marker, Popup, Polyline, Polygon, TileLayer, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import { Trash2 } from 'lucide-react';

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


interface TacticalMapProps {
    raceState: any;
    activeTab: string;
    selectedTool: string | null;
    drawingMode: boolean;
    zoom: number;
    autoOrient: boolean;
    draggingMarkId: React.MutableRefObject<string | null>;
    socket: any;
    setRaceState: React.Dispatch<React.SetStateAction<any>>;
    renderBuoyIcon: (mark: any, size: number, autoOrient: boolean) => L.DivIcon;
    LaylineLayer: React.FC<any>;
    CourseBoundaryDrawing: React.FC<any>;
    onDeleteMark?: (id: string) => void;
}

const TacticalMap = ({
    raceState,
    activeTab,
    selectedTool,
    drawingMode,
    zoom,
    autoOrient,
    draggingMarkId,
    socket,
    setRaceState,
    renderBuoyIcon,
    LaylineLayer,
    CourseBoundaryDrawing,
    onDeleteMark
}: TacticalMapProps) => {
    const map = useMapEvents({
        moveend: () => {
            if (activeTab === 'designer' || activeTab === 'fleet') {
                const center = map.getCenter();
                const currentZoom = map.getZoom();
                socket?.emit('update-default-location', { lat: center.lat, lon: center.lng, zoom: currentZoom });
            }
        }
    });
    const [localMarks, setLocalMarks] = useState(raceState.course.marks);

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

            <CourseBoundaryDrawing isDrawing={drawingMode} boundary={raceState.course.courseBoundary} setBoundary={(b: any) => socket?.emit('update-course', { ...raceState.course, courseBoundary: b })} />

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
                    {(() => {
                        const starts = localMarks.filter((m: any) => m.type === 'START');
                        if (starts.length === 2) {
                            return <Polyline positions={[[starts[0].pos.lat, starts[0].pos.lon], [starts[1].pos.lat, starts[1].pos.lon]]} pathOptions={{ color: '#fbbf24', weight: 4, dashArray: '10, 10' }} />;
                        }
                        return null;
                    })()}
                    {(() => {
                        const finishes = localMarks.filter((m: any) => m.type === 'FINISH');
                        if (finishes.length === 2) {
                            return <Polyline positions={[[finishes[0].pos.lat, finishes[0].pos.lon], [finishes[1].pos.lat, finishes[1].pos.lon]]} pathOptions={{ color: '#3b82f6', weight: 4, dashArray: '10, 10' }} />;
                        }
                        return null;
                    })()}
                </>
            )}

            {localMarks.map((mark: any) => (
                <Marker
                    key={mark.id}
                    position={[mark.pos.lat, mark.pos.lon]}
                    draggable={activeTab === 'designer' && !selectedTool}
                    eventHandlers={{
                        dragstart: () => {
                            draggingMarkId.current = mark.id;
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
                            const updatedMarks = localMarks.map((m: any) => m.id === mark.id ? { ...m, pos: { lat: position.lat, lon: position.lng } } : m);
                            const updatedCourse = { ...raceState.course, marks: updatedMarks };

                            // Force sync back to React state on end
                            setLocalMarks(updatedMarks);
                            setRaceState((prev: any) => ({ ...prev, course: updatedCourse }));
                            socket?.emit('update-course', updatedCourse);

                            setTimeout(() => {
                                draggingMarkId.current = null;
                            }, 50);
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
                                <div className="flex gap-1 justify-center py-1">
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
            {Object.entries(raceState.boats).map(([id, boat]: [string, any]) => (
                <Marker
                    key={id}
                    position={[boat.pos.lat, boat.pos.lon]}
                    icon={BOAT_ICON(boat.imu?.heading || 0)}
                />
            ))}
        </>
    );
};

export default React.memo(TacticalMap);
