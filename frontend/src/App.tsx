import { useState, useEffect, useRef } from 'react'
import { MapContainer, useMapEvents, Polyline, Marker, Polygon, CircleMarker } from 'react-leaflet'
import React from 'react'
import { io, Socket } from 'socket.io-client'
import {
    Layout, Flag, Wind, Navigation, Users, Settings, Activity,
    Map as MapIcon, Plus, Trash2,
    MoreHorizontal,
    Monitor,
    FileCog
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import L from 'leaflet'

import TrackerMock from './TrackerMock'
import JuryApp from './JuryApp'
import MediaHub from './MediaHub'
import StartingTimeline from './components/StartingTimeline'
import ErrorBoundary from './components/ErrorBoundary'
import ProcedureDesigner from './components/procedure-designer/ProcedureDesigner'
import TacticalMap from './components/TacticalMap'

// --- Types ---
interface Buoy {
    id: string;
    type: 'MARK' | 'START' | 'FINISH' | 'GATE';
    name: string;
    pos: { lat: number, lon: number };
    color?: string;
    rounding?: 'PORT' | 'STARBOARD';
    pairId?: string;
    gateDirection?: 'UPWIND' | 'DOWNWIND';
    design?: 'POLE' | 'BUOY' | 'TUBE' | 'MARKSETBOT';
}

interface RaceState {
    status: 'IDLE' | 'PRE_START' | 'RACING' | 'FINISHED' | 'POSTPONED' | 'RECALL' | 'ABANDONED';
    currentSequence: string | null;
    sequenceTimeRemaining: number | null;
    startTime: number | null;
    wind: { direction: number, speed: number };
    course: {
        marks: Buoy[];
        startLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        finishLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        courseBoundary: { lat: number, lon: number }[] | null;
    };
    defaultLocation?: { lat: number, lon: number, zoom: number };
    boats: Record<string, any>;
    prepFlag: string;
    currentFlags: string[];
    currentEvent: string | null;
    currentProcedure: any | null;
    currentNodeId: string | null;
}

// --- Icons ---
const renderBuoyIcon = (mark: Buoy, size: number, autoOrient: boolean = false) => {
    const color = mark.color === 'yellow' ? '#fbbf24' : mark.color === 'orange' ? '#f97316' : mark.color === 'red' ? '#ef4444' : mark.color === 'green' ? '#22c55e' : '#3b82f6';
    let content = '';

    switch (mark.design) {
        case 'POLE':
            content = `
                <div style="position: relative; width: ${size}px; height: ${size}px; display: flex; flex-direction: column; align-items: center;">
                    <div style="width: 2px; height: 100%; background: #666;"></div>
                    <div style="position: absolute; top: 0; left: 50%; width: ${size / 1.5}px; height: ${size / 2.5}px; background: ${color}; border: 1px solid rgba(255,255,255,0.3);"></div>
                </div>
            `;
            break;
        case 'TUBE':
            content = `
                <div style="width: ${size / 2}px; height: ${size}px; background: ${color}; border-radius: 2px; border: 2px solid rgba(255,255,255,0.5); box-shadow: 0 4px 6px rgba(0,0,0,0.3);"></div>
            `;
            break;
        case 'MARKSETBOT':
            content = `
                <div style="position: relative; width: ${size}px; height: ${size}px; display: flex; align-items: center; justify-content: center;">
                    <div style="width: ${size}px; height: ${size / 2}px; background: #333; border-radius: 4px;"></div>
                    <div style="position: absolute; top: 0; width: ${size / 2}px; height: ${size / 2}px; background: ${color}; border-radius: 50%; border: 2px solid white;"></div>
                    <div style="position: absolute; bottom: 0; width: 4px; height: 4px; background: #fff; border-radius: 50%; box-shadow: 0 0 5px orange;"></div>
                </div>
            `;
            break;
        case 'BUOY':
        default:
            content = `
                <div style="width: ${size}px; height: ${size}px; background: ${color}; border-radius: 50%; border: 2px solid rgba(255,255,255,0.7); box-shadow: 0 4px 6px rgba(0,0,0,0.3);"></div>
            `;
    }

    return L.divIcon({
        className: `marker-buoy-custom ${autoOrient ? 'unrotate-marker' : ''}`,
        html: content,
        iconSize: [size, size],
        iconAnchor: [size / 2, size] // Anchored at the "feet"
    });
};

// --- UI Sub-components ---

const NavIcon = ({ icon: Icon, active = false, onClick }: any) => (
    <button
        onClick={onClick}
        className={`p-4 rounded-2xl transition-all relative ${active ? 'bg-accent-blue/20 text-accent-blue' : 'text-gray-400 hover:text-white hover:bg-white/5'}`}
    >
        {active && <motion.div layoutId="nav-bg" className="absolute inset-0 bg-accent-blue/10 blur-xl rounded-full" />}
        <Icon size={24} className="relative z-10" />
    </button>
)

const GlassPanel = ({ title, children, icon: Icon, className = "" }: any) => (
    <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className={`bg-regatta-panel/80 backdrop-blur-xl border border-white/10 rounded-3xl p-6 shadow-2xl flex flex-col ${className}`}
    >
        <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
                {Icon && <Icon size={18} className="text-accent-blue" />}
                <h3 className="text-xs font-bold uppercase tracking-[0.25em] text-gray-400">{title}</h3>
            </div>
            <MoreHorizontal size={18} className="text-gray-600" />
        </div>
        {children}
    </motion.div>
)

const DesignerTool = ({ label, active, onClick }: any) => (
    <button
        onClick={onClick}
        className={`p-4 rounded-xl border text-[10px] font-bold uppercase tracking-widest transition-all
               ${active ? 'bg-accent-blue border-accent-blue text-white shadow-lg' : 'bg-white/5 border-white/5 text-gray-400 hover:bg-white/10'}`}
    >
        {label}
    </button>
)



// --- Map Events for Designer ---
const CourseDesignerEvents = ({ onAddMark, isEditing, selectedTool, drawingMode }: { onAddMark: (latlng: any) => void, isEditing: boolean, selectedTool: string | null, drawingMode: boolean }) => {
    useMapEvents({
        click(e) {
            if (isEditing && selectedTool && selectedTool !== 'BOUNDARY' && !drawingMode) {
                // Ensure we are not clicking on a marker or popup
                const originalEvent = e.originalEvent;
                const target = originalEvent.target as HTMLElement;

                // If the target is a leaflet marker or inside a popup, ignore
                if (target.closest('.leaflet-marker-icon') || target.closest('.leaflet-popup')) return;

                onAddMark(e.latlng);
            }
        },
    });
    return null;
}

const WindControl = ({ wind, onChange }: { wind: { direction: number, speed: number }, onChange: (w: any) => void }) => {
    const [isEditing, setIsEditing] = useState(false);

    return (
        <GlassPanel title="Wind Control" icon={Wind} className="pointer-events-auto">
            <div className="flex items-center justify-between">
                <div>
                    <div className="flex items-end gap-2 mb-2">
                        <input
                            type="number"
                            value={wind.speed}
                            onChange={(e) => onChange({ ...wind, speed: Number(e.target.value) })}
                            className="bg-transparent text-5xl font-black italic tracking-tighter leading-none text-white w-24 outline-none border-b border-white/10 focus:border-accent-blue transition-colors"
                        />
                        <span className="text-sm font-bold text-gray-500 not-italic mb-1 opacity-60">KTS</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <input
                            type="range"
                            min="0"
                            max="360"
                            value={wind.direction}
                            onChange={(e) => onChange({ ...wind, direction: Number(e.target.value) })}
                            className="w-32 accent-accent-cyan"
                        />
                        <span className="text-[10px] font-bold text-accent-cyan uppercase tracking-widest">{wind.direction}°</span>
                    </div>
                </div>
                <div className="w-20 h-20 rounded-full border-2 border-white/10 flex items-center justify-center relative bg-white/5 shadow-inner group cursor-pointer" onClick={() => setIsEditing(!isEditing)}>
                    <motion.div
                        animate={{ rotate: wind.direction }}
                        transition={{ type: "spring", stiffness: 50 }}
                        className="text-accent-blue drop-shadow-glow-blue"
                    >
                        <svg viewBox="0 0 24 24" width="40" height="40" fill="currentColor">
                            <path d="M12 2L4.5 20.29L5.21 21L12 18L18.79 21L19.5 20.29L12 2Z" />
                        </svg>
                    </motion.div>
                    <span className="absolute -top-3 left-1/2 -translate-x-1/2 text-[9px] font-black text-gray-600 bg-regatta-panel px-1">N</span>
                </div>
            </div>
        </GlassPanel>
    )
}

const WindArrowLayer = ({ boundary, windDir }: { boundary: { lat: number, lon: number }[] | null, windDir: number }) => {
    if (!boundary || boundary.length < 3) return null;

    // Calculate center of boundary
    const latSum = boundary.reduce((acc, p) => acc + p.lat, 0);
    const lonSum = boundary.reduce((acc, p) => acc + p.lon, 0);
    const center = { lat: latSum / boundary.length, lon: lonSum / boundary.length };

    // Calculate position outside boundary (approx 0.01 degree offset)
    const offset = 0.015;
    const rad = (windDir - 180) * Math.PI / 180; // Pointing FROM the wind direction
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

const LaylineLayer = ({ marks, windDir, boundary }: { marks: Buoy[], windDir: number, boundary: { lat: number, lon: number }[] | null }) => {
    if (!marks.length) return null;

    // Helper to find intersection of a ray with the boundary polygon
    const findBoundaryIntersection = (start: { lat: number, lon: number }, bearing: number) => {
        if (!boundary || boundary.length < 3) {
            // Fallback to old behavior if no boundary
            const R = 6371;
            const d = 2.0 / R; // 2km fallback
            const lat1 = start.lat * Math.PI / 180;
            const lon1 = start.lon * Math.PI / 180;
            const brng = bearing * Math.PI / 180;
            const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng));
            const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));
            return { lat: lat2 * 180 / Math.PI, lon: lon2 * 180 / Math.PI };
        }

        // Raycasting to find intersection with boundary segments
        // Simplified: just extend far and use a line intersection helper
        const extendDist = 5.0; // 5km to ensure it reaches boundary
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
                const d = Math.sqrt(Math.pow(intersection.lat - start.lat, 2) + Math.pow(intersection.lon - start.lon, 2));
                if (d < closestDist) {
                    closestDist = d;
                    bestPoint = intersection;
                }
            }
        }
        return bestPoint;
    };

    return (
        <>
            {marks.filter(m => m.type === 'MARK' || m.type === 'GATE' || m.type === 'START' || m.type === 'FINISH').map(m => {
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



const CourseBoundaryDrawing = ({
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

    useEffect(() => {
        if (boundary && boundary.length > 2 && !isDrawing) {
            // Auto zoom to boundary when created or loaded if needed
            const bounds = L.latLngBounds(boundary.map(p => [p.lat, p.lon]));
            if (bounds.isValid()) map.flyToBounds(bounds, { padding: [50, 50], duration: 1.5 });
        }
    }, [boundary, isDrawing]); /** Depend on isDrawing to zoom ONLY when finished */

    if (!boundary) return null;

    return (
        <>
            {boundary.length > 1 && (
                <Polygon
                    positions={boundary.map(p => [p.lat, p.lon])}
                    pathOptions={{
                        color: 'rgba(6,182,212,0.8)',
                        weight: 2,
                        dashArray: isDrawing ? '10, 10' : undefined,
                        fillColor: 'rgba(6,182,212,0.1)',
                        fillOpacity: 0.2
                    }}
                />
            )}
            {boundary.map((p, i) => (
                <CircleMarker
                    key={i}
                    center={[p.lat, p.lon]}
                    radius={4}
                    pathOptions={{ color: 'white', fillColor: 'cyan', fillOpacity: 1 }}
                />
            ))}
        </>
    )
}

// --- Main App ---

export default function App() {
    const [view, setView] = useState<'management' | 'tracker' | 'jury' | 'media'>('management')
    const [activeTab, setActiveTab] = useState<'overview' | 'designer' | 'procedure' | 'procedure-editor' | 'boats' | 'tracking' | 'settings'>('overview')
    const [socket, setSocket] = useState<Socket | null>(null)
    const [mapInstance, setMapInstance] = useState<L.Map | null>(null)
    const [zoom, setZoom] = useState(14)
    const [showSaveSuccess, setShowSaveSuccess] = useState(false)
    const [selectedTool, setSelectedTool] = useState<'MARK' | 'GATE' | 'START' | 'FINISH' | 'BOUNDARY' | null>(null)
    const draggingMarkId = useRef<string | null>(null);

    const [raceState, setRaceState] = useState<RaceState>({
        status: 'IDLE',
        currentSequence: null,
        sequenceTimeRemaining: null,
        startTime: null,
        wind: { direction: 0, speed: 0 },
        course: { marks: [], startLine: null, finishLine: null, courseBoundary: null },
        boats: {},
        prepFlag: 'P',
        currentFlags: [],
        currentEvent: null,
        currentProcedure: null,
        currentNodeId: null,
    })

    // Local UI State
    const [_isDesignerActive, setIsDesignerActive] = useState(false)
    const [drawingMode, setDrawingMode] = useState(false)
    const [autoOrient, setAutoOrient] = useState(false)

    // URL Routing Support
    useEffect(() => {
        const params = new URLSearchParams(window.location.search);
        const urlView = params.get('view');
        if (urlView === 'tracker') {
            setView('tracker');
        } else if (urlView === 'media') {
            setView('media');
        } else if (urlView === 'jury') {
            setView('jury');
        }
    }, []);

    useEffect(() => {
        const s = io('http://localhost:3001')
        setSocket(s)

        s.on('connect', () => {
            s.emit('register', { type: 'management' })
        })

        s.on('init-state', (state: any) => {
            // Flatten backend nested structure to frontend state
            setRaceState({
                ...state,
                // Ensure array even if backend is missing it
                boats: state.boats || {},
                currentFlags: state.currentSequence?.flags || [],
                currentEvent: state.currentSequence?.event || null,
                prepFlag: state.prepFlag || 'P', // Default to P if missing
                currentProcedure: state.currentProcedure || null,
                currentNodeId: state.currentNodeId || null,
            })
        })
        s.on('boat-update', (data) => {
            setRaceState(prev => ({
                ...prev,
                boats: { ...prev.boats, [data.boatId]: data }
            }))
        })
        s.on('course-updated', (course) => setRaceState(prev => {
            if (draggingMarkId.current) return prev;
            return { ...prev, course };
        }))
        s.on('wind-updated', (wind) => setRaceState(prev => ({ ...prev, wind })))
        s.on('state-update', (state: any) => setRaceState(prev => ({
            ...prev,
            ...state,
            currentFlags: state.currentSequence?.flags || prev.currentFlags,
            currentEvent: state.currentSequence?.event || prev.currentEvent,
        })))
        s.on('sequence-update', (data) => setRaceState(prev => ({
            ...prev,
            status: data.status || prev.status,
            sequenceTimeRemaining: data.time !== undefined ? data.time : prev.sequenceTimeRemaining,
            currentSequence: data.event || prev.currentSequence,
            currentFlags: data.flags || prev.currentFlags,
            currentEvent: data.event || prev.currentEvent,
            prepFlag: data.prepFlag || prev.prepFlag,
            currentNodeId: data.currentNodeId || prev.currentNodeId,
        })))
        s.on('race-started', (data) => setRaceState(prev => ({
            ...prev,
            status: 'RACING',
            startTime: data.startTime,
            sequenceTimeRemaining: 0,
            currentFlags: [],
            currentEvent: 'STARTED',
        })))

        s.on('kill-simulation', (id) => {
            console.log('[FRONTEND] Received kill-simulation command for:', id);
            setRaceState(prev => {
                const newBoats = { ...prev.boats };
                if (id === 'all') {
                    console.log('[FRONTEND] Clearing all boats from state');
                    return { ...prev, boats: {} };
                }
                console.log(`[FRONTEND] Removing boat ${id} from state`);
                delete newBoats[id];
                return { ...prev, boats: newBoats };
            });
        });

        return () => { s.close() }
    }, [view])

    // Effect for Map Events
    useEffect(() => {
        if (!mapInstance) return;

        const updateZoom = () => setZoom(mapInstance.getZoom());
        mapInstance.on('zoomend', updateZoom);

        return () => {
            mapInstance.off('zoomend', updateZoom);
        };
    }, [mapInstance]);

    // Effect for Map Initialization & Sync
    useEffect(() => {
        if (!mapInstance || !socket) return;

        // On initial load or state refresh, fly to course or default
        if (raceState.course.courseBoundary && raceState.course.courseBoundary.length >= 3) {
            const bounds = L.latLngBounds(raceState.course.courseBoundary.map(p => [p.lat, p.lon]));
            mapInstance.flyToBounds(bounds, { padding: [100, 100], duration: 1.5 });
        } else if (raceState.defaultLocation) {
            mapInstance.flyTo(
                [raceState.defaultLocation.lat, raceState.defaultLocation.lon],
                raceState.defaultLocation.zoom,
                { duration: 1.5 }
            );
        }
    }, [mapInstance, !!socket]);

    // Handlers
    const handleAddMark = (latlng: any) => {
        if (!selectedTool) return;

        let newMarks: Buoy[] = [];
        const baseId = Math.random().toString(36).substr(2, 9);

        if (selectedTool === 'MARK') {
            newMarks.push({
                id: baseId,
                type: 'MARK',
                name: `Mark ${raceState.course.marks.filter(m => m.type === 'MARK').length + 1}`,
                pos: { lat: latlng.lat, lon: latlng.lng },
                design: 'BUOY',
                color: 'orange'
            });
        } else if (selectedTool === 'GATE' || selectedTool === 'START' || selectedTool === 'FINISH') {
            // Deploy as a pair
            const type = selectedTool as any;
            const nameBase = type === 'GATE' ? 'Gate' : type === 'START' ? 'Start' : 'Finish';
            const count = raceState.course.marks.filter(m => m.type === type).length / 2 + 1;

            // Offset second mark slightly to create a line
            const offset = 0.0005;
            newMarks.push({
                id: baseId + '-1',
                type: type,
                pairId: baseId,
                name: `${nameBase} ${count} L`,
                pos: { lat: latlng.lat, lon: latlng.lng - offset },
                design: 'BUOY',
                color: type === 'START' ? 'yellow' : type === 'FINISH' ? 'blue' : 'orange',
                gateDirection: type === 'GATE' ? 'DOWNWIND' : undefined
            });
            newMarks.push({
                id: baseId + '-2',
                type: type,
                pairId: baseId,
                name: `${nameBase} ${count} R`,
                pos: { lat: latlng.lat, lon: latlng.lng + offset },
                design: 'BUOY',
                color: type === 'START' ? 'yellow' : type === 'FINISH' ? 'blue' : 'orange',
                gateDirection: type === 'GATE' ? 'DOWNWIND' : undefined
            });
        }

        if (newMarks.length > 0) {
            const updatedCourse = { ...raceState.course, marks: [...raceState.course.marks, ...newMarks] };
            socket?.emit('update-course', updatedCourse);
            // Optionally clear tool after deployment? User didn't specify, but often helpful.
            // For now, keep it selected for "rapid deployment".
        }
    }

    const handleUpdateBoundary = (boundary: { lat: number, lon: number }[] | null) => {
        const updatedCourse = { ...raceState.course, courseBoundary: boundary };
        setRaceState(prev => ({ ...prev, course: updatedCourse }));
        socket?.emit('update-course-boundary', boundary)
    }

    const handleUpdateWind = (newWind: any) => {
        setRaceState(prev => ({ ...prev, wind: newWind }));
        socket?.emit('update-wind', newWind);
    }

    const handleDeleteMark = (id: string) => {
        const updatedMarks = raceState.course.marks.filter(m => m.id !== id && m.pairId !== id)
        socket?.emit('update-course', { ...raceState.course, marks: updatedMarks })
    }

    const handleClearAll = () => {
        socket?.emit('update-course', { marks: [], startLine: null, finishLine: null, courseBoundary: null })
    }

    const formatTime = (seconds: number) => {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m}:${s.toString().padStart(2, '0')}`;
    }

    if (view === 'tracker') return <TrackerMock />;
    if (view === 'jury') return <JuryApp />;
    if (view === 'media') return <MediaHub />;

    return (
        <div className="flex h-screen w-screen bg-regatta-dark text-white overflow-hidden selection:bg-accent-blue/30">

            {/* Left Navigation Bar */}
            <nav className="w-24 bg-black/40 border-r border-white/5 flex flex-col items-center py-10 gap-8 z-50 backdrop-blur-md">
                <div className="w-14 h-14 bg-accent-blue rounded-2xl flex items-center justify-center shadow-[0_0_40px_rgba(59,130,246,0.6)] mb-6 hover:scale-105 transition-transform duration-500">
                    <Navigation className="text-white fill-current" size={28} />
                </div>
                <div className="flex flex-col gap-6 w-full px-4">
                    <NavIcon icon={Layout} active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} />
                    <NavIcon icon={MapIcon} active={activeTab === 'designer'} onClick={() => { setActiveTab('designer'); setIsDesignerActive(true) }} />
                    <NavIcon icon={Flag} active={activeTab === 'procedure'} onClick={() => setActiveTab('procedure')} />
                    <NavIcon icon={FileCog} active={activeTab === 'procedure-editor'} onClick={() => setActiveTab('procedure-editor')} />
                    <div className="h-px w-8 bg-white/10 my-2" />
                    <NavIcon icon={Settings} active={activeTab === 'settings'} onClick={() => setActiveTab('settings')} />
                </div>
                <div className="mt-auto flex flex-col gap-6 w-full px-4">
                    <NavIcon icon={Monitor} onClick={() => setView('media')} />
                </div>
            </nav>

            {/* Main Experience Container */}
            <div className="flex-1 flex flex-col relative bg-gradient-to-br from-regatta-dark to-black">

                {/* Top Cinematic Header (Floating) */}
                <header className="absolute top-0 left-0 right-0 h-28 px-12 flex items-center justify-between z-40 bg-gradient-to-b from-black/90 via-black/50 to-transparent pointer-events-none">
                    <div className="flex items-center gap-10 pointer-events-auto">
                        <div>
                            <h1 className="text-4xl font-black italic tracking-tighter uppercase leading-none text-transparent bg-clip-text bg-gradient-to-r from-white via-blue-100 to-white drop-shadow-[0_0_20px_rgba(59,130,246,0.5)]">
                                REGATTA <span className="text-accent-blue">PRO</span>
                            </h1>
                            <div className="flex items-center gap-3 mt-2 text-[10px] font-bold text-gray-400 uppercase tracking-[0.3em]">
                                <div className="flex items-center gap-1.5">
                                    <span className={`w-1.5 h-1.5 rounded-full ${socket?.connected ? 'bg-accent-green shadow-[0_0_10px_#22c55e]' : 'bg-accent-red'} animate-pulse`} />
                                    {socket?.connected ? 'Live Data Feed' : 'Offline'}
                                </div>
                                <span className="text-white/20">|</span>
                                STHLM ARCHIPELAGO
                            </div>
                        </div>

                        <div className="flex gap-3">
                            <button onClick={() => setView('tracker')} className="px-5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-[10px] font-bold uppercase tracking-widest hover:bg-white/10 hover:border-white/20 transition-all backdrop-blur-md">
                                Tracker View
                            </button>
                            <button onClick={() => setView('jury')} className="px-5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-[10px] font-bold uppercase tracking-widest hover:bg-white/10 hover:border-white/20 transition-all backdrop-blur-md">
                                Jury Console
                            </button>
                        </div>
                    </div>

                    <div className="flex items-center gap-8 pointer-events-auto">
                        <div className="flex flex-col items-end">
                            <div className="text-[9px] font-black text-gray-500 uppercase tracking-[0.3em] mb-1">J70 Procedure Status</div>
                            <div className="flex items-center gap-4">
                                <AnimatePresence mode="wait">
                                    {raceState.status === 'PRE_START' && (
                                        <motion.div
                                            key="timer"
                                            initial={{ opacity: 0, scale: 0.8, filter: 'blur(10px)' }}
                                            animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
                                            exit={{ opacity: 0, scale: 1.1, filter: 'blur(10px)' }}
                                            className="text-4xl font-black italic tracking-tighter tabular-nums text-accent-cyan drop-shadow-[0_0_15px_rgba(6,182,212,0.6)]"
                                        >
                                            {formatTime(raceState.sequenceTimeRemaining || 0)}
                                        </motion.div>
                                    )}
                                </AnimatePresence>
                                <div className={`px-5 py-2 rounded-full text-[10px] font-black uppercase tracking-widest border ${raceState.status === 'RACING' ? 'bg-accent-green/20 border-accent-green/50 text-accent-green shadow-[0_0_20px_rgba(34,197,94,0.3)]' : 'bg-white/5 border-white/10 text-gray-400'}`}>
                                    {raceState.status.replace('_', ' ')}
                                </div>
                            </div>
                        </div>

                        <button
                            onClick={() => setAutoOrient(!autoOrient)}
                            className={`h-14 px-6 rounded-2xl font-black uppercase tracking-widest text-[10px] flex items-center gap-3 transition-all duration-300 border ${autoOrient ? 'bg-accent-cyan/20 border-accent-cyan text-accent-cyan shadow-[0_0_20px_rgba(6,182,212,0.3)]' : 'bg-white/5 border-white/10 text-gray-400'}`}
                        >
                            <Navigation size={14} className={autoOrient ? 'animate-pulse' : ''} /> {autoOrient ? 'Orient: Wind' : 'Orient: North'}
                        </button>
                    </div>
                </header>

                {/* Tactical Map Layer */}
                <div className="absolute inset-0 z-0 bg-regatta-dark">
                    <MapContainer
                        center={[59.3293, 18.0686]}
                        zoom={14}
                        zoomControl={false}
                        ref={setMapInstance}
                        className={`w-full h-full grayscale-[0.2] contrast-[1.1] transition-transform duration-1000 ease-in-out ${autoOrient ? 'rotated-map-container' : ''}`}
                        style={{
                            transform: autoOrient ? `rotate(${360 - raceState.wind.direction}deg)` : 'none',
                            '--inverse-rotation': autoOrient ? `${raceState.wind.direction}deg` : '0deg'
                        } as React.CSSProperties}
                    >
                        <TacticalMap
                            raceState={raceState}
                            activeTab={activeTab}
                            selectedTool={selectedTool}
                            drawingMode={drawingMode}
                            zoom={zoom}
                            autoOrient={autoOrient}
                            draggingMarkId={draggingMarkId}
                            socket={socket}
                            setRaceState={setRaceState}
                            renderBuoyIcon={renderBuoyIcon}
                            LaylineLayer={LaylineLayer}
                            CourseBoundaryDrawing={CourseBoundaryDrawing}
                            onDeleteMark={handleDeleteMark}
                        />

                        <CourseDesignerEvents
                            isEditing={activeTab === 'designer'}
                            selectedTool={selectedTool}
                            drawingMode={drawingMode}
                            onAddMark={handleAddMark}
                        />
                        <WindArrowLayer boundary={raceState.course.courseBoundary} windDir={raceState.wind.direction} />
                    </MapContainer>

                    {/* Vignette Overlay for Focus */}
                    <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(circle_at_center,transparent_20%,rgba(15,23,42,0.6)_100%)]" />
                </div>

                {/* Floating HUD Container (Anchored below header) */}
                <div className="absolute top-32 bottom-0 left-0 right-0 z-10 p-12 flex gap-10 pointer-events-none">

                    {/* Left Wing Panels */}
                    <AnimatePresence>
                        {activeTab === 'overview' && (
                            <motion.div
                                key="overview"
                                initial={{ x: -20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: -20, opacity: 0 }}
                                className="w-96 h-full flex flex-col"
                            >
                                <GlassPanel title="Race Control Center" icon={Layout} className="pointer-events-auto h-full">
                                    <div className="flex-1 overflow-y-auto pr-2 space-y-6">
                                        {/* Wind Card */}
                                        <div className="p-5 rounded-2xl bg-gradient-to-br from-accent-blue/20 to-transparent border border-white/10">
                                            <div className="text-[10px] font-black text-accent-blue uppercase tracking-widest mb-4">Tactical Wind Environment</div>
                                            <div className="flex items-center justify-between">
                                                <div>
                                                    <div className="text-3xl font-black italic tracking-tighter text-white">{raceState.wind.speed.toFixed(1)}<span className="text-xs font-normal not-italic text-gray-500 ml-1 uppercase">kts</span></div>
                                                    <div className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-1">Steady Breeze</div>
                                                </div>
                                                <div className="text-right">
                                                    <div className="text-3xl font-black italic tracking-tighter text-accent-cyan">{raceState.wind.direction}°</div>
                                                    <div className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-1">Direction (TWA)</div>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Race Progress Card */}
                                        <div className="p-5 rounded-2xl bg-white/5 border border-white/5">
                                            <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Live Race Intelligence</div>
                                            <div className="space-y-4">
                                                <div className="flex items-center justify-between">
                                                    <span className="text-[10px] font-bold text-gray-500 uppercase">Status</span>
                                                    <span className="text-[10px] font-black uppercase text-accent-green">{raceState.status}</span>
                                                </div>
                                                <div className="flex items-center justify-between">
                                                    <span className="text-[10px] font-bold text-gray-500 uppercase">Active Marks</span>
                                                    <span className="text-[10px] font-black uppercase text-white">{raceState.course.marks.length} deployed</span>
                                                </div>
                                                <div className="flex items-center justify-between">
                                                    <span className="text-[10px] font-bold text-gray-500 uppercase">Fleet Size</span>
                                                    <span className="text-[10px] font-black uppercase text-white">{Object.keys(raceState.boats).length} tracked</span>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Quick Actions */}
                                        <div className="space-y-3">
                                            <button
                                                onClick={() => setActiveTab('procedure')}
                                                className="w-full py-4 bg-accent-blue hover:bg-blue-600 text-white rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                            >
                                                Launch Procedure
                                            </button>
                                            <button
                                                onClick={() => setActiveTab('procedure-editor')}
                                                className="w-full py-4 bg-accent-cyan/10 hover:bg-accent-cyan/20 border border-accent-cyan/30 text-accent-cyan rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                            >
                                                Procedure Editor
                                            </button>
                                            <button
                                                onClick={() => setActiveTab('designer')}
                                                className="w-full py-4 bg-white/5 hover:bg-white/10 border border-white/10 text-white rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                            >
                                                Course Designer
                                            </button>
                                        </div>
                                    </div>
                                </GlassPanel>
                            </motion.div>
                        )}

                        {activeTab === 'designer' && (
                            <motion.div
                                key="designer"
                                initial={{ x: -20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: -20, opacity: 0 }}
                                className="w-96 h-full flex flex-col"
                            >
                                <GlassPanel title="Course Designer" icon={MapIcon} className="pointer-events-auto h-full">
                                    <div className="flex-1 overflow-y-auto pr-2 space-y-4">
                                        <div className="grid grid-cols-2 gap-3 mb-6">
                                            <DesignerTool
                                                label="Single Mark"
                                                active={selectedTool === 'MARK'}
                                                onClick={() => {
                                                    if (!raceState.course.courseBoundary) return;
                                                    setSelectedTool(selectedTool === 'MARK' ? null : 'MARK');
                                                    setDrawingMode(false);
                                                }}
                                            />
                                            <DesignerTool
                                                label="Gate"
                                                active={selectedTool === 'GATE'}
                                                onClick={() => {
                                                    if (!raceState.course.courseBoundary) return;
                                                    setSelectedTool(selectedTool === 'GATE' ? null : 'GATE');
                                                    setDrawingMode(false);
                                                }}
                                            />
                                            <DesignerTool
                                                label="Start Line"
                                                active={selectedTool === 'START'}
                                                onClick={() => {
                                                    if (!raceState.course.courseBoundary) return;
                                                    setSelectedTool(selectedTool === 'START' ? null : 'START');
                                                    setDrawingMode(false);
                                                }}
                                            />
                                            <DesignerTool
                                                label="Finish Line"
                                                active={selectedTool === 'FINISH'}
                                                onClick={() => {
                                                    if (!raceState.course.courseBoundary) return;
                                                    setSelectedTool(selectedTool === 'FINISH' ? null : 'FINISH');
                                                    setDrawingMode(false);
                                                }}
                                            />
                                        </div>

                                        {!raceState.course.courseBoundary && (
                                            <div className="p-4 rounded-xl bg-accent-red/10 border border-accent-red/20 mb-4">
                                                <p className="text-[10px] text-accent-red font-bold uppercase leading-relaxed text-center">
                                                    You must set the Course Boundary before adding marks.
                                                </p>
                                            </div>
                                        )}

                                        <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4 border-b border-white/5 pb-2">Active Buoys ({raceState.course.marks.length})</div>

                                        {raceState.course.marks.map((m) => (
                                            <div key={m.id} className="p-4 rounded-xl bg-white/5 flex items-center justify-between group hover:bg-white/10 transition-all border border-white/5 hover:border-accent-blue/30 cursor-pointer">
                                                <div className="flex items-center gap-4">
                                                    <div className="w-10 h-10 rounded-lg bg-accent-blue/10 flex items-center justify-center text-accent-blue font-black italic shadow-inner">
                                                        {m.name.charAt(0)}
                                                    </div>
                                                    <div>
                                                        <div className="text-xs font-bold uppercase tracking-tight text-gray-200">{m.name}</div>
                                                        <div className="text-[9px] text-gray-500 font-mono mt-0.5">{m.pos.lat.toFixed(4)}, {m.pos.lon.toFixed(4)}</div>
                                                    </div>
                                                </div>
                                                <Trash2
                                                    size={14}
                                                    className="text-gray-600 hover:text-accent-red transition-colors"
                                                    onClick={(e) => { e.stopPropagation(); handleDeleteMark(m.id); }}
                                                />
                                            </div>
                                        ))}

                                        {raceState.course.marks.length === 0 && (
                                            <div className="flex flex-col items-center justify-center py-20 text-center opacity-40 border-2 border-dashed border-white/10 rounded-2xl">
                                                <Plus className="mb-4 text-accent-blue" size={32} />
                                                <span className="text-[10px] font-bold uppercase tracking-widest">Click Intelligence Map<br />to Deploy Marks</span>
                                            </div>
                                        )}
                                    </div>
                                    <div className="mt-6 pt-6 border-t border-white/10 flex flex-col gap-3">
                                        {!drawingMode ? (
                                            <button
                                                onClick={() => {
                                                    setDrawingMode(true);
                                                    setSelectedTool(null);
                                                }}
                                                className="w-full py-4 bg-white/5 hover:bg-white/10 border border-white/10 text-white rounded-xl text-[10px] font-black uppercase tracking-[0.25em] transition-all"
                                            >
                                                {raceState.course.courseBoundary ? 'Edit Boundary' : 'Add Course Boundary'}
                                            </button>
                                        ) : (
                                            <button
                                                onClick={() => setDrawingMode(false)}
                                                className="w-full py-4 bg-accent-green text-white rounded-xl text-[10px] font-black uppercase tracking-[0.25em] shadow-lg shadow-accent-green/20 hover:shadow-accent-green/40 transition-all"
                                            >
                                                Finish Drawing
                                            </button>
                                        )}

                                        {raceState.course.courseBoundary && !drawingMode && (
                                            <button
                                                onClick={() => handleUpdateBoundary(null)}
                                                className="w-full py-3 text-accent-red hover:bg-accent-red/10 rounded-xl text-[9px] font-bold uppercase tracking-widest transition-all"
                                            >
                                                Clear Boundary
                                            </button>
                                        )}

                                        <button className="w-full py-4 bg-accent-blue text-white rounded-xl text-[10px] font-black uppercase tracking-[0.25em] shadow-lg shadow-accent-blue/20 hover:shadow-accent-blue/40 transition-all">
                                            Sync Course Data
                                        </button>
                                    </div>
                                </GlassPanel>
                            </motion.div>
                        )}

                        {activeTab === 'procedure' && (
                            <motion.div
                                key="procedure"
                                initial={{ x: -20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: -20, opacity: 0 }}
                                className="w-[420px] h-full flex flex-col"
                            >
                                <GlassPanel title="Starting Procedure (RRS 26)" icon={Flag} className="pointer-events-auto h-full">
                                    <ErrorBoundary>
                                        <StartingTimeline
                                            socket={socket}
                                            raceStatus={raceState.status}
                                            sequenceTimeRemaining={raceState.sequenceTimeRemaining}
                                            currentFlags={raceState.currentFlags}
                                            currentEvent={raceState.currentEvent}
                                            prepFlag={raceState.prepFlag}
                                            currentProcedure={raceState.currentProcedure}
                                            currentNodeId={raceState.currentNodeId}
                                        />
                                    </ErrorBoundary>
                                </GlassPanel>
                            </motion.div>
                        )}

                        {activeTab === 'settings' && (
                            <motion.div
                                key="settings"
                                initial={{ x: -20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: -20, opacity: 0 }}
                                className="w-96 h-full flex flex-col"
                            >
                                <GlassPanel title="System Settings" icon={Settings} className="pointer-events-auto h-full">
                                    <div className="space-y-6">
                                        <div className="p-6 rounded-2xl bg-white/5 border border-white/10">
                                            <div className="text-[10px] font-black text-accent-blue uppercase tracking-widest mb-4">Map Configuration</div>
                                            <p className="text-xs text-gray-400 mb-6 leading-relaxed">
                                                Set the current view as the default starting position for all users when no course is defined.
                                            </p>
                                            <button
                                                onClick={() => {
                                                    if (!mapInstance) return;
                                                    const center = mapInstance.getCenter();
                                                    const z = mapInstance.getZoom();
                                                    socket?.emit('update-default-location', { lat: center.lat, lon: center.lng, zoom: z });
                                                    setShowSaveSuccess(true);
                                                    setTimeout(() => setShowSaveSuccess(false), 2000);
                                                }}
                                                className={`w-full py-4 border rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all ${showSaveSuccess ? 'bg-accent-green/20 border-accent-green text-accent-green' : 'bg-accent-blue/10 hover:bg-accent-blue/20 border-accent-blue/50 text-accent-blue'}`}
                                            >
                                                {showSaveSuccess ? 'Location Locked!' : 'Lock Current Map Location'}
                                            </button>
                                        </div>

                                        <div className="p-6 rounded-2xl bg-white/5 border border-white/10">
                                            <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4">Reset Tools</div>
                                            <button
                                                onClick={handleClearAll}
                                                className="w-full py-4 bg-accent-red/10 hover:bg-accent-red/20 border border-accent-red/50 text-accent-red rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all"
                                            >
                                                Wipe All Course Data
                                            </button>
                                        </div>
                                    </div>
                                </GlassPanel>
                            </motion.div>
                        )}
                    </AnimatePresence>

                    {/* Spacer */}
                    <div className="flex-1" />

                    {/* Right Wing (Always Visible) */}
                    <div className="w-96 flex flex-col gap-6">
                        <WindControl wind={raceState.wind} onChange={handleUpdateWind} />

                        <GlassPanel title="Fleet Telemetry" icon={Users} className="pointer-events-auto flex-1 min-h-0">
                            <div className="flex-1 overflow-y-auto pr-2 space-y-4 custom-scrollbar">
                                {Object.entries(raceState.boats).map(([id, boat]: [string, any]) => (
                                    <div key={id} className="p-5 rounded-2xl bg-white/5 border border-white/5 hover:border-accent-blue/40 transition-all group backdrop-blur-sm cursor-pointer">
                                        <div className="flex justify-between items-start mb-5">
                                            <div className="flex items-center gap-4">
                                                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-accent-blue/20 to-transparent flex items-center justify-center text-sm font-black italic text-accent-blue border border-white/5 group-hover:border-accent-blue/30 transition-all">
                                                    {id.substring(0, 2).toUpperCase()}
                                                </div>
                                                <div>
                                                    <div className="text-xs font-black uppercase italic tracking-tight text-white">{id.substring(0, 8)}</div>
                                                    <div className="text-[9px] font-bold text-gray-500 uppercase tracking-widest mt-0.5">Signal Strong</div>
                                                </div>
                                            </div>
                                            <div className="flex items-center gap-2 bg-black/40 px-2 py-1 rounded-lg">
                                                <div className={`w-1.5 h-1.5 rounded-full ${boat.dtl < 2 ? 'bg-accent-red animate-pulse' : 'bg-accent-green'}`} />
                                                <span className={`text-[9px] font-black uppercase ${boat.dtl < 2 ? 'text-accent-red' : 'text-accent-green'}`}>{boat.dtl < 2 ? 'OCS' : 'SAFE'}</span>
                                            </div>
                                        </div>

                                        <div className="grid grid-cols-2 gap-4">
                                            <div className="p-3 bg-black/40 rounded-xl border border-white/5">
                                                <div className="text-[8px] font-black text-blue-400 uppercase tracking-widest mb-1 opacity-70">SOG</div>
                                                <div className="text-xl font-black italic tracking-tighter">{boat.velocity?.speed || '0.0'}<span className="text-[9px] font-normal not-italic text-gray-500 ml-1 uppercase">kn</span></div>
                                            </div>
                                            <div className="p-3 bg-black/40 rounded-xl border border-white/5">
                                                <div className="text-[8px] font-black text-cyan-400 uppercase tracking-widest mb-1 opacity-70">DTL</div>
                                                <div className="text-xl font-black italic tracking-tighter text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.3)]">{boat.dtl?.toFixed(1) || '0.0'}<span className="text-[9px] font-normal not-italic text-gray-500 ml-1 uppercase">M</span></div>
                                            </div>
                                        </div>

                                        <div className="grid grid-cols-2 gap-3 mt-4">
                                            <button
                                                onClick={() => window.open(`/?view=tracker&boatId=${id}`, '_blank')}
                                                className="py-2 bg-accent-blue/10 hover:bg-accent-blue/20 border border-accent-blue/30 text-accent-blue rounded-lg text-[8px] font-black uppercase tracking-widest transition-all"
                                            >
                                                Access
                                            </button>
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    console.log('[UI] Sending kill simulation for:', id);
                                                    if (socket) {
                                                        socket.emit('kill-tracker', id);
                                                    } else {
                                                        console.error('[UI] Socket connection not found');
                                                    }
                                                }}
                                                className="py-2 bg-accent-red/10 hover:bg-accent-red/20 border border-accent-red/30 text-accent-red rounded-lg text-[8px] font-black uppercase tracking-widest transition-all"
                                            >
                                                Kill
                                            </button>
                                        </div>
                                    </div>
                                ))}

                                {Object.keys(raceState.boats).length === 0 && (
                                    <div className="flex flex-col items-center justify-center h-full text-center opacity-30 pb-10">
                                        <Activity size={48} className="mb-4 text-gray-500" />
                                        <span className="text-[10px] font-black uppercase tracking-[0.2em] text-gray-400">Waiting for Uplink...</span>
                                    </div>
                                )}

                                {Object.keys(raceState.boats).length > 0 && (
                                    <button
                                        onClick={() => {
                                            if (confirm('Definitively clear the entire fleet?')) {
                                                console.log('[UI] Requesting fleet-wide clear');
                                                if (socket) {
                                                    socket.emit('clear-fleet');
                                                } else {
                                                    console.error('[UI] Socket connection not found');
                                                }
                                            }
                                        }}
                                        className="w-full sticky bottom-0 py-4 bg-accent-red/10 hover:bg-accent-red/20 border border-accent-red/20 hover:border-accent-red/40 text-accent-red rounded-xl text-[10px] font-black uppercase tracking-widest transition-all shadow-xl backdrop-blur-md"
                                    >
                                        Clear All Trackers
                                    </button>
                                )}
                            </div>
                        </GlassPanel>
                    </div>

                </div>

                {/* Procedure Editor Overlay (Outside regular HUD flow) */}
                <AnimatePresence>
                    {activeTab === 'procedure-editor' && (
                        <motion.div
                            key="procedure-editor"
                            initial={{ opacity: 0, scale: 0.98 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 1.02 }}
                            className="absolute inset-0 z-[100] bg-regatta-dark/95 backdrop-blur-2xl flex flex-col pointer-events-auto"
                        >
                            <div className="h-20 px-12 flex items-center justify-between border-b border-white/10 bg-black/40">
                                <div className="flex items-center gap-6">
                                    <div className="p-3 bg-accent-blue/20 rounded-xl text-accent-blue">
                                        <FileCog size={24} />
                                    </div>
                                    <div>
                                        <h2 className="text-xl font-black italic tracking-tighter uppercase text-white">Start Logic Architect</h2>
                                        <div className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Procedural Sequence Engine</div>
                                    </div>
                                </div>
                                <button
                                    onClick={() => setActiveTab('procedure')}
                                    className="px-8 py-3 bg-white/5 hover:bg-accent-red/20 border border-white/10 hover:border-accent-red/50 text-white hover:text-accent-red rounded-xl text-[10px] font-black uppercase tracking-widest transition-all shadow-lg"
                                >
                                    Close Architect
                                </button>
                            </div>
                            <div className="flex-1 relative border-t border-white/5 bg-slate-900/50">
                                <div className="absolute top-2 left-6 z-[110] text-[8px] font-black text-white/20 uppercase tracking-[0.5em] pointer-events-none">Logic Canvas Active</div>
                                <ErrorBoundary>
                                    <ProcedureDesigner currentProcedure={raceState.currentProcedure} />
                                </ErrorBoundary>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </div >
        </div >
    )
}
