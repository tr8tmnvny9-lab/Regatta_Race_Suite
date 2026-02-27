import React, { useState, useEffect, useRef } from 'react'
import { MapContainer } from 'react-leaflet'

import {
    Layout, Flag, Navigation, Users, Settings, Activity,
    Map as MapIcon, Plus, Trash2,
    Monitor,
    FileCog,
    Play,
    QrCode,
    X,
    Lock,
    Sun,
    Moon,
    Cpu
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import L from 'leaflet'

import TrackerMock from './TrackerMock'
import JuryApp from './JuryApp'
import MediaSuite from './MediaSuite'
import StartingTimeline from './components/StartingTimeline'
import ErrorBoundary from './components/ErrorBoundary'
import ProcedureEditor from './components/ProcedureEditor'
import TacticalMap from './components/TacticalMap'
import LogView from './components/LogView'
import { GlassPanel, NavIcon, DesignerTool, WindControl } from './components/UIHelperComponents'
import { WindArrowLayer, LaylineLayer, CourseBoundaryDrawing, CourseDesignerEvents } from './components/MapLayers'
import { Buoy, RaceState as CoreRaceState, RegattaEngine, LogEntry } from '@regatta/core'
import RaceOnboarding from './components/RaceOnboarding'
import FleetControl from './views/FleetControl'
import UWBSimulator from './views/UWBSimulator'

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

// --- Main App ---

export default function App() {
    const [view, setView] = useState<'management' | 'tracker' | 'jury' | 'media'>('management')
    const [activeTab, setActiveTab] = useState<'OVERVIEW' | 'FLEET' | 'DESIGNER' | 'PROCEDURE' | 'ARCHITECT' | 'LOGS' | 'SETTINGS' | 'SIMULATOR'>('OVERVIEW')
    const [onboardingOpen, setOnboardingOpen] = useState(false)
    const [engine, setEngine] = useState<RegattaEngine | null>(null)
    const [mapInstance, setMapInstance] = useState<L.Map | null>(null)
    const [zoom, setZoom] = useState(14)
    const [showSaveSuccess, setShowSaveSuccess] = useState(false)
    const [isFetchingWeather, setIsFetchingWeather] = useState(false)
    const [showHeatmap, setShowHeatmap] = useState(false)
    const [playbackTime, setPlaybackTime] = useState<number | null>(null)
    const [syncDrag, setSyncDrag] = useState(true)
    const [selectedTool, setSelectedTool] = useState<'MARK' | 'GATE' | 'START' | 'FINISH' | 'BOUNDARY' | 'MEASURE' | null>(null)
    const [measurePoints, setMeasurePoints] = useState<{ lat: number, lon: number }[]>([])
    const draggingMarkId = useRef<string | null>(null);

    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [selectedRole, setSelectedRole] = useState('director');

    const [latency, setLatency] = useState<number | null>(null);
    const [isDaylight, setIsDaylight] = useState(false);

    const [raceState, setRaceState] = useState<CoreRaceState>({
        status: 'IDLE',
        currentSequence: null,
        sequenceTimeRemaining: null,
        startTime: null,
        wind: { direction: 180, speed: 12 },
        course: {
            marks: [],
            startLine: null,
            finishLine: null,
            courseBoundary: null
        },
        boats: {},
        prepFlag: 'P',
        currentFlags: [],
        currentEvent: null,
        currentProcedure: null,
        currentNodeId: null,
        logs: []
    })

    // Local UI State
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

    // Wait for authentication before connecting
    useEffect(() => {
        if (!isAuthenticated) return;

        const url = 'http://localhost:3001'
        const regattaEngine = new RegattaEngine(url, selectedRole) // role token determines permissions
        regattaEngine.connect()
        setEngine(regattaEngine)

        // The Engine handles its own 'connect' event, we just listen to state updates now.
        regattaEngine.onStateChange((state) => {
            // Flatten backend nested structure to frontend state
            setRaceState({
                ...state,
                // Ensure array even if backend is missing it
                boats: state.boats || {},
                currentFlags: (state.currentSequence as any)?.flags || [],
                currentEvent: (state.currentSequence as any)?.event || null,
                prepFlag: state.prepFlag || 'P', // Default to P if missing
                currentProcedure: state.currentProcedure || null,
                currentNodeId: state.currentNodeId || null,
                logs: state.logs || [],
                waitingForTrigger: state.waitingForTrigger,
                actionLabel: state.actionLabel,
                isPostTrigger: state.isPostTrigger,
                // Fleet Management fields (essential for FleetControl to work)
                teams: (state as any).teams || {},
                flights: (state as any).flights || {},
                pairings: (state as any).pairings || [],
                fleetSettings: (state as any).fleetSettings || { mode: 'OWNER', providedBoatsCount: 6 },
                activeFlightId: (state as any).activeFlightId || null,
            })
        })

        regattaEngine.onLogsChange((logs) => {
            setRaceState(prev => ({
                ...prev,
                logs: [...logs, ...prev.logs].slice(0, 100)
            }))
        })

        // NOTE: The previous hardcoded raw listeners for 'init-state', 'state-update', 'race-started' 
        // are now gracefully abstracted inside the Engine or handled generically via state sync.

        // NOTE: A temporary patch until RegattaEngine is fully built out
        // The Engine currently only supports sequence/boat/logs.
        // I need to expand regatta-core's RegattaEngine to support full state bindings.

        if (regattaEngine.socket) {
            regattaEngine.socket.on('latency-pong', (data: any) => {
                if (data && data.t) {
                    setLatency(Date.now() - data.t);
                }
            });
        }

        const pingInterval = setInterval(() => {
            if (regattaEngine.socket?.connected) {
                const s = regattaEngine.socket as any;
                if (s.volatile) {
                    s.volatile.emit('latency-ping', { t: Date.now() });
                } else {
                    regattaEngine.socket.emit('latency-ping', { t: Date.now() });
                }
            }
        }, 2000);

        return () => {
            clearInterval(pingInterval);
            regattaEngine.disconnect()
        }
    }, [view, isAuthenticated, selectedRole])

    // Effect for Map Events
    useEffect(() => {
        if (!mapInstance) return;

        const updateZoom = () => setZoom(mapInstance.getZoom());
        mapInstance.on('zoomend', updateZoom);

        return () => {
            mapInstance.off('zoomend', updateZoom);
        };
    }, [mapInstance]);

    useEffect(() => {
        if (!mapInstance || !engine) return;

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
    }, [mapInstance, !!engine]);

    // Handlers
    const handleAddMark = (latlng: any) => {
        if (!selectedTool) return;

        if (selectedTool === 'MEASURE') {
            setMeasurePoints(prev => prev.length >= 2 ? [{ lat: latlng.lat, lon: latlng.lng }] : [...prev, { lat: latlng.lat, lon: latlng.lng }]);
            return;
        }

        let newMarks: Buoy[] = [];
        const baseId = Math.random().toString(36).substr(2, 9);

        if (selectedTool === 'MARK') {
            newMarks.push({
                id: baseId,
                type: 'MARK',
                name: `Mark ${raceState.course.marks.filter(m => m.type === 'MARK').length + 1} `,
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
            engine?.emit('update-course', updatedCourse);
            // Optionally clear tool after deployment? User didn't specify, but often helpful.
            // For now, keep it selected for "rapid deployment".
        }
    }

    const handleUpdateBoundary = (boundary: { lat: number, lon: number }[] | null) => {
        const updatedCourse = { ...raceState.course, courseBoundary: boundary };
        setRaceState(prev => ({ ...prev, course: updatedCourse }));
        engine?.emit('update-course-boundary', boundary)
    }

    const handleUpdateWind = (newWind: any) => {
        setRaceState(prev => ({ ...prev, wind: newWind }));
        engine?.emit('update-wind', newWind);
    }

    const handleFetchWeather = async () => {
        setIsFetchingWeather(true);
        try {
            // Use course boundary center or default location, fallback to Stockholm Archipelago
            const lat = raceState.course.courseBoundary?.[0]?.lat || raceState.defaultLocation?.lat || 59.3293;
            const lon = raceState.course.courseBoundary?.[0]?.lon || raceState.defaultLocation?.lon || 18.0686;

            const res = await fetch(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=wind_speed_10m,wind_direction_10m&wind_speed_unit=kn`);
            const data = await res.json();

            if (data?.current) {
                const direction = Math.round(data.current.wind_direction_10m);
                const speed = Math.round(data.current.wind_speed_10m * 10) / 10;
                handleUpdateWind({ direction, speed });
            }
        } catch (err) {
            console.error("OpenMeteo fetch failed:", err);
        } finally {
            setIsFetchingWeather(false);
        }
    }

    const handleDeleteMark = (id: string) => {
        const updatedMarks = raceState.course.marks.filter(m => m.id !== id && m.pairId !== id)
        engine?.emit('update-course', { ...raceState.course, marks: updatedMarks })
    }

    const handleClearAll = () => {
        engine?.emit('update-course', { marks: [], startLine: null, finishLine: null, courseBoundary: null })
    }

    const projectLocation = (lat: number, lon: number, bearingDeg: number, distanceNm: number) => {
        const R = 6378.137; // Earth radius in km
        const d = (distanceNm * 1.852) / R;
        const lat1 = lat * Math.PI / 180;
        const lon1 = lon * Math.PI / 180;
        const brng = bearingDeg * Math.PI / 180;

        const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng));
        const lon2 = lon1 + Math.atan2(Math.sin(brng) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));

        return { lat: lat2 * 180 / Math.PI, lon: lon2 * 180 / Math.PI };
    }

    const getCenterPoint = () => {
        if (raceState.course.courseBoundary && raceState.course.courseBoundary.length > 0) {
            const latSum = raceState.course.courseBoundary.reduce((acc, p) => acc + p.lat, 0);
            const lonSum = raceState.course.courseBoundary.reduce((acc, p) => acc + p.lon, 0);
            return { lat: latSum / raceState.course.courseBoundary.length, lon: lonSum / raceState.course.courseBoundary.length };
        }
        return mapInstance ? { lat: mapInstance.getCenter().lat, lon: mapInstance.getCenter().lng } : { lat: 59.3293, lon: 18.0686 };
    }

    const handleExportMarkSetBot = () => {
        const msbCourse = {
            courseName: `Regatta Suite Export - ${new Date().toISOString()}`,
            windDirection: raceState.wind.direction,
            windSpeed: raceState.wind.speed,
            marks: raceState.course.marks.map((m: any) => ({
                id: m.id,
                name: m.name,
                type: m.type,
                latitude: m.pos.lat,
                longitude: m.pos.lon,
                design: m.design || 'MARKSETBOT'
            }))
        };
        const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(msbCourse, null, 2));
        const downloadAnchorNode = document.createElement('a');
        downloadAnchorNode.setAttribute("href", dataStr);
        downloadAnchorNode.setAttribute("download", "marksetbot_course.json");
        document.body.appendChild(downloadAnchorNode);
        downloadAnchorNode.click();
        downloadAnchorNode.remove();
    }

    const handleUpdateLog = (updatedLog: LogEntry) => {
        engine?.emit('update-log', updatedLog);
        setRaceState((prev: any) => ({
            ...prev,
            logs: prev.logs.map((l: LogEntry) => l.id === updatedLog.id ? updatedLog : l)
        }));
    }

    const handleGenerateWindwardLeeward = () => {
        if (!confirm("This will overwrite your existing marks. Continue?")) return;

        const center = getCenterPoint();
        const wd = raceState.wind.direction;
        const upwindBearing = wd;
        const downwindBearing = (wd + 180) % 360;
        const legLengthNm = 1.0; // 1 Nautical Mile legs
        const lineLengthNm = 0.1;

        // Mark 1 (Windward)
        const mark1 = projectLocation(center.lat, center.lon, upwindBearing, legLengthNm / 2);
        // Leeward Gate (Center)
        const gateCenter = projectLocation(center.lat, center.lon, downwindBearing, legLengthNm / 2);
        const g1 = projectLocation(gateCenter.lat, gateCenter.lon, (downwindBearing + 90) % 360, lineLengthNm / 2);
        const g2 = projectLocation(gateCenter.lat, gateCenter.lon, (downwindBearing - 90 + 360) % 360, lineLengthNm / 2);

        // Start Line (Below Gate)
        const startCenter = projectLocation(gateCenter.lat, gateCenter.lon, downwindBearing, 0.1);
        const s1 = projectLocation(startCenter.lat, startCenter.lon, (downwindBearing + 90) % 360, lineLengthNm / 2);
        const s2 = projectLocation(startCenter.lat, startCenter.lon, (downwindBearing - 90 + 360) % 360, lineLengthNm / 2);

        // Finish Line (Above Mark 1)
        const finishCenter = projectLocation(mark1.lat, mark1.lon, upwindBearing, 0.1);
        const f1 = projectLocation(finishCenter.lat, finishCenter.lon, (downwindBearing + 90) % 360, lineLengthNm / 2);
        const f2 = projectLocation(finishCenter.lat, finishCenter.lon, (downwindBearing - 90 + 360) % 360, lineLengthNm / 2);

        const newMarks = [
            { id: 'w1', type: 'MARK', name: 'Mark 1', pos: mark1, design: 'BUOY', color: 'orange' },
            { id: 'g1', pairId: 'gate', type: 'GATE', name: 'Gate L', pos: g1, design: 'BUOY', color: 'orange', gateDirection: 'DOWNWIND' },
            { id: 'g2', pairId: 'gate', type: 'GATE', name: 'Gate R', pos: g2, design: 'BUOY', color: 'orange', gateDirection: 'DOWNWIND' },
            { id: 's1', pairId: 'start', type: 'START', name: 'Start Port', pos: s1, design: 'POLE', color: 'yellow' },
            { id: 's2', pairId: 'start', type: 'START', name: 'Start Stbd', pos: s2, design: 'MARKSETBOT', color: 'yellow' },
            { id: 'f1', pairId: 'finish', type: 'FINISH', name: 'Finish Port', pos: f1, design: 'POLE', color: 'blue' },
            { id: 'f2', pairId: 'finish', type: 'FINISH', name: 'Finish Stbd', pos: f2, design: 'MARKSETBOT', color: 'blue' }
        ];

        engine?.emit('update-course', { ...raceState.course, marks: newMarks });
    }

    const handleGenerateOlympicTriangle = () => {
        if (!confirm("This will overwrite your existing marks. Continue?")) return;

        const center = getCenterPoint();
        const wd = raceState.wind.direction;
        const upwindBearing = wd;
        const downwindBearing = (wd + 180) % 360;
        const legLengthNm = 1.0;
        const lineLengthNm = 0.1;

        // Mark 1 (Windward)
        const mark1 = projectLocation(center.lat, center.lon, upwindBearing, legLengthNm / 2);
        // Mark 3 (Leeward)
        const mark3Center = projectLocation(center.lat, center.lon, downwindBearing, legLengthNm / 2);
        const mark3Params = projectLocation(mark3Center.lat, mark3Center.lon, downwindBearing, 0); // exact

        // Mark 2 (Reach) - Triangle pointing port side
        // Distance Mark1 -> Mark2 is roughly 0.7 NM for a 45/45/90 triangle (0.5 * sqrt(2))
        // But let's just project from center directly to left side of the axis
        const mark2 = projectLocation(center.lat, center.lon, (downwindBearing - 90 + 360) % 360, legLengthNm / 2);

        // Start Line
        const startCenter = projectLocation(mark3Params.lat, mark3Params.lon, downwindBearing, 0.1);
        const s1 = projectLocation(startCenter.lat, startCenter.lon, (downwindBearing + 90) % 360, lineLengthNm / 2);
        const s2 = projectLocation(startCenter.lat, startCenter.lon, (downwindBearing - 90 + 360) % 360, lineLengthNm / 2);

        const newMarks = [
            { id: 'o1', type: 'MARK', name: 'Mark 1 (Windward)', pos: mark1, design: 'BUOY', color: 'orange' },
            { id: 'o2', type: 'MARK', name: 'Mark 2 (Reach)', pos: mark2, design: 'BUOY', color: 'orange' },
            { id: 'o3', type: 'MARK', name: 'Mark 3 (Leeward)', pos: mark3Params, design: 'BUOY', color: 'orange' },
            { id: 's1', pairId: 'start', type: 'START', name: 'Start Port', pos: s1, design: 'POLE', color: 'yellow' },
            { id: 's2', pairId: 'start', type: 'START', name: 'Start Stbd', pos: s2, design: 'MARKSETBOT', color: 'yellow' }
        ];

        engine?.emit('update-course', { ...raceState.course, marks: newMarks });
    }

    const formatTime = (seconds: number) => {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m}:${s.toString().padStart(2, '0')} `;
    }

    // ─── LOGIN SCREEN ───
    if (!isAuthenticated) {
        const roles = [
            { value: 'director', label: 'Race Director / PRO', description: 'Full race control — sequence, flags, procedures' },
            { value: 'jury', label: 'Jury Member', description: 'Protest & penalty management view' },
            { value: 'media', label: 'Media / Broadcast', description: 'Live data feed, leaderboard, no control' },
        ];
        return (
            <div className="fixed inset-0 bg-regatta-dark flex items-center justify-center z-[9999]">
                <div className="absolute inset-0 overflow-hidden pointer-events-none">
                    <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] bg-accent-blue/10 blur-[120px] rounded-full" />
                    <div className="absolute bottom-[-20%] right-[-10%] w-[50%] h-[50%] bg-accent-cyan/10 blur-[120px] rounded-full" />
                </div>

                <motion.div
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="relative w-full max-w-md bg-white/5 backdrop-blur-3xl border border-white/10 p-8 rounded-3xl shadow-2xl flex flex-col gap-6"
                >
                    <div className="text-center space-y-2">
                        <div className="flex justify-center mb-4">
                            <div className="p-4 bg-accent-blue/10 rounded-2xl border border-accent-blue/20 text-accent-cyan">
                                <Lock size={32} />
                            </div>
                        </div>
                        <h1 className="text-3xl font-black italic tracking-tighter uppercase text-white drop-shadow-lg">
                            Regatta <span className="text-transparent bg-clip-text bg-gradient-to-r from-accent-blue to-accent-cyan">Pro</span>
                        </h1>
                        <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">
                            Select your role to connect
                        </p>
                    </div>

                    <div className="space-y-3">
                        {roles.map(role => (
                            <button
                                key={role.value}
                                onClick={() => setSelectedRole(role.value)}
                                className={`w-full p-4 rounded-2xl border text-left transition-all ${selectedRole === role.value
                                    ? 'bg-accent-blue/20 border-accent-blue/50 shadow-[0_0_20px_rgba(59,130,246,0.2)]'
                                    : 'bg-white/5 border-white/10 hover:bg-white/10'
                                    }`}
                            >
                                <div className={`font-bold text-sm tracking-wide ${selectedRole === role.value ? 'text-accent-blue' : 'text-white'}`}>
                                    {role.label}
                                </div>
                                <div className="text-xs text-gray-500 mt-0.5">{role.description}</div>
                            </button>
                        ))}
                    </div>

                    <button
                        onClick={() => setIsAuthenticated(true)}
                        className="w-full bg-gradient-to-r from-accent-blue to-accent-cyan text-white font-black italic uppercase tracking-widest py-3 rounded-xl shadow-[0_0_20px_rgba(59,130,246,0.3)] hover:shadow-[0_0_30px_rgba(6,182,212,0.5)] hover:scale-[1.02] transition-all"
                    >
                        Connect as {roles.find(r => r.value === selectedRole)?.label}
                    </button>

                    <p className="text-center text-[10px] text-gray-600 font-mono">
                        Connecting to localhost:3001 · Regatta Backend
                    </p>
                </motion.div>
            </div>
        )
    }

    if (view === 'tracker') return <TrackerMock />;
    if (!engine || !raceState) return <div className="min-h-screen bg-[#050507] flex items-center justify-center"><div className="w-12 h-12 border-4 border-accent-blue border-t-transparent flex items-center justify-center rounded-full animate-spin" /></div>;

    if (view === 'jury') return <JuryApp socket={engine.socket} raceState={raceState} />;
    if (view === 'media') return <MediaSuite socket={engine.socket} raceState={raceState} onHome={() => setView('management')} />;
    return (
        <div className={`flex h-screen w-screen bg-regatta-dark text-white overflow-hidden selection:bg-accent-blue/30 transition-colors duration-700 ${isDaylight ? 'daylight-theme' : ''}`}>

            {/* Left Navigation Bar */}
            <nav className="w-24 bg-black/40 border-r border-white/5 flex flex-col items-center py-10 gap-8 z-50 backdrop-blur-md">
                <div className="w-14 h-14 bg-accent-blue rounded-2xl flex items-center justify-center shadow-[0_0_40px_rgba(59,130,246,0.6)] mb-6 hover:scale-105 transition-transform duration-500">
                    <Navigation className="text-white fill-current" size={28} />
                </div>
                <div className="flex flex-col gap-6 w-full px-4 text-center">
                    <NavIcon icon={Layout} active={activeTab === 'OVERVIEW'} onClick={() => setActiveTab('OVERVIEW')} />
                    <NavIcon icon={Users} active={activeTab === 'FLEET'} onClick={() => setActiveTab('FLEET')} />
                    <NavIcon icon={MapIcon} active={activeTab === 'DESIGNER'} onClick={() => setActiveTab('DESIGNER')} />
                    <NavIcon icon={Activity} active={activeTab === 'LOGS'} onClick={() => setActiveTab('LOGS')} />
                    <NavIcon icon={Flag} active={activeTab === 'PROCEDURE'} onClick={() => setActiveTab('PROCEDURE')} />
                    <NavIcon icon={FileCog} active={activeTab === 'ARCHITECT'} onClick={() => setActiveTab('ARCHITECT')} />
                    <NavIcon icon={Cpu} active={activeTab === 'SIMULATOR'} onClick={() => setActiveTab('SIMULATOR')} />

                    {/* Latency Indicator */}
                    <div className="flex flex-col items-center gap-1 opacity-60 hover:opacity-100 transition-opacity my-4">
                        <div className={`w-2 h-2 rounded-full ${latency === null ? 'bg-gray-500' : latency < 50 ? 'bg-green-500' : latency < 150 ? 'bg-yellow-500' : 'bg-red-500'} shadow-[0_0_10px_currentColor]`} />
                        <span className="text-[9px] font-mono tracking-tighter text-gray-400">{latency !== null ? `${latency}ms` : '---'}</span>
                    </div>

                    <div className="h-px w-8 bg-white/10 mx-auto my-2" />

                    {/* Theme Toggle */}
                    <button
                        onClick={() => setIsDaylight(!isDaylight)}
                        className="w-10 h-10 rounded-xl flex items-center justify-center bg-white/5 hover:bg-white/10 border border-white/5 transition-all opacity-60 hover:opacity-100 mb-2"
                        title={isDaylight ? "Switch to Night Mode" : "Switch to Day Mode"}
                    >
                        {isDaylight ? <Moon size={18} className="text-accent-blue" /> : <Sun size={18} className="text-yellow-500" />}
                    </button>

                    <NavIcon icon={Settings} active={activeTab === 'SETTINGS'} onClick={() => setActiveTab('SETTINGS')} />
                </div>
                <div className="mt-auto flex flex-col gap-6 w-full px-4 text-center">
                    <NavIcon icon={Monitor} onClick={() => setView('media')} />
                    <NavIcon icon={QrCode} onClick={() => setOnboardingOpen(true)} />
                </div>
            </nav>

            {/* QR Onboarding Modal */}
            <AnimatePresence>
                {onboardingOpen && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="fixed inset-0 z-[999] flex items-center justify-center"
                        onClick={() => setOnboardingOpen(false)}
                    >
                        <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
                        <motion.div
                            initial={{ opacity: 0, scale: 0.95, y: 10 }}
                            animate={{ opacity: 1, scale: 1, y: 0 }}
                            exit={{ opacity: 0, scale: 0.95, y: 10 }}
                            className="relative z-10 bg-[#111]/95 border border-white/10 rounded-3xl shadow-2xl w-[380px] p-6"
                            onClick={e => e.stopPropagation()}
                        >
                            <button onClick={() => setOnboardingOpen(false)} className="absolute top-4 right-4 text-white/40 hover:text-white/80 transition-colors">
                                <X size={18} />
                            </button>
                            <RaceOnboarding />
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Main Experience Container */}
            <div className="flex-1 flex flex-col relative bg-gradient-to-br from-regatta-dark to-black" >

                {/* Top Cinematic Header (Floating) */}
                <header className="absolute top-0 left-0 right-0 h-28 px-12 flex items-center justify-between z-40 bg-gradient-to-b from-black/90 via-black/50 to-transparent pointer-events-none">
                    <div className="flex items-center gap-10 pointer-events-auto">
                        <div>
                            <h1 className="text-4xl font-black italic tracking-tighter uppercase leading-none text-transparent bg-clip-text bg-gradient-to-r from-white via-blue-100 to-white drop-shadow-[0_0_20px_rgba(59,130,246,0.5)]">
                                REGATTA <span className="text-accent-blue">PRO</span>
                            </h1>
                            <div className="flex items-center gap-3 mt-2 text-[10px] font-bold text-gray-400 uppercase tracking-[0.3em]">
                                <div className="flex items-center gap-1.5">
                                    <span className={`w-1.5 h-1.5 rounded-full ${engine?.connected ? 'bg-accent-green shadow-[0_0_10px_#22c55e]' : 'bg-accent-red'} animate-pulse`} />
                                    {engine?.connected ? 'Live Data Feed' : 'Offline'}
                                </div>
                                <span className="text-white/20">|</span>
                                STHLM ARCHIPELAGO
                            </div>
                        </div>

                        <div className="flex gap-3">
                            {raceState.status === 'IDLE' && (
                                <button onClick={() => engine?.emit('start-sequence', { minutes: 5, prepFlag: raceState.prepFlag })} className="flex items-center justify-center gap-2 px-5 py-2.5 bg-accent-blue/20 text-accent-blue border border-accent-blue/30 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-accent-blue hover:text-white transition-colors">
                                    <Play size={14} /> Start 5-Min
                                </button>
                            )}

                            {['WARNING', 'PREPARATORY', 'ONE_MINUTE', 'START', 'RACING'].includes(raceState.status) && (
                                <>
                                    <button onClick={() => { if (confirm('Are you sure you want to General Recall the fleet?')) engine?.emit('procedure-action', { action: 'GENERAL_RECALL' }) }} className="px-5 py-2.5 bg-amber-500/10 border border-amber-500/30 text-amber-500 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-amber-500/20 hover:border-amber-500/50 transition-all backdrop-blur-md">
                                        General Recall
                                    </button>
                                    <button onClick={() => { if (confirm('Are you sure you want to completely Abandon this race?')) engine?.emit('procedure-action', { action: 'ABANDON' }) }} className="px-5 py-2.5 bg-red-500/10 border border-red-500/30 text-red-400 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-red-500/20 hover:border-red-500/50 transition-all backdrop-blur-md">
                                        Abandon Race
                                    </button>
                                </>
                            )}

                            {['GENERAL_RECALL', 'POSTPONED', 'ABANDONED', 'FINISHED'].includes(raceState.status) && (
                                <button onClick={() => engine?.emit('procedure-action', { action: 'RESET' })} className="px-5 py-2.5 bg-white/5 border border-white/10 text-gray-300 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-white/10 hover:border-white/30 transition-all backdrop-blur-md">
                                    Reset to Idle
                                </button>
                            )}

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
                                    {['WARNING', 'PREPARATORY', 'ONE_MINUTE'].includes(raceState.status) && (
                                        <motion.div
                                            key="timer"
                                            initial={{ opacity: 0, scale: 0.8, filter: 'blur(10px)' }}
                                            animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
                                            exit={{ opacity: 0, scale: 1.1, filter: 'blur(10px)' }}
                                            className={`text-4xl font-black italic tracking-tighter tabular-nums drop-shadow-lg ${raceState.status === 'ONE_MINUTE' ? 'text-accent-red drop-shadow-[0_0_15px_rgba(239,68,68,0.6)]' : 'text-accent-cyan drop-shadow-[0_0_15px_rgba(6,182,212,0.6)]'}`}
                                        >
                                            {formatTime(raceState.sequenceTimeRemaining || 0)}
                                        </motion.div>
                                    )}
                                </AnimatePresence>
                                <div className={`px-5 py-2 rounded-full text-[10px] font-black uppercase tracking-widest border ${raceState.status === 'RACING' ? 'bg-accent-green/20 border-accent-green/50 text-accent-green shadow-[0_0_20px_rgba(34,197,94,0.3)]'
                                    : raceState.status === 'ONE_MINUTE' ? 'bg-red-500/20 border-red-500/50 text-red-400 animate-pulse'
                                        : ['WARNING', 'PREPARATORY'].includes(raceState.status) ? 'bg-accent-cyan/20 border-accent-cyan/50 text-accent-cyan'
                                            : ['POSTPONED', 'INDIVIDUAL_RECALL', 'GENERAL_RECALL'].includes(raceState.status) ? 'bg-amber-500/20 border-amber-500/50 text-amber-400'
                                                : raceState.status === 'ABANDONED' ? 'bg-red-500/20 border-red-500/50 text-red-400'
                                                    : raceState.status === 'FINISHED' ? 'bg-gray-500/20 border-gray-500/50 text-gray-400'
                                                        : 'bg-white/5 border-white/10 text-gray-400'
                                    }`}>
                                    {raceState.status.replace(/_/g, ' ')}
                                </div>
                            </div>
                        </div>

                        <button
                            onClick={() => setShowHeatmap(!showHeatmap)}
                            className={`h-14 px-6 rounded-2xl font-black uppercase tracking-widest text-[10px] flex items-center gap-3 transition-all duration-300 border ${showHeatmap ? 'bg-accent-red/20 border-accent-red text-accent-red shadow-[0_0_20px_rgba(239,68,68,0.3)]' : 'bg-white/5 border-white/10 text-gray-400'}`}
                        >
                            <Activity size={14} className={showHeatmap ? 'animate-pulse' : ''} /> {showHeatmap ? 'Heatmap: On' : 'Heatmap: Off'}
                        </button>
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
                            showHeatmap={showHeatmap}
                            syncDrag={syncDrag}
                            measurePoints={measurePoints}
                            draggingMarkId={draggingMarkId}
                            playbackTime={playbackTime}
                            socket={engine.socket as any}
                            setRaceState={setRaceState}
                            renderBuoyIcon={renderBuoyIcon}
                            LaylineLayer={LaylineLayer}
                            CourseBoundaryDrawing={CourseBoundaryDrawing}
                            onUpdateBoundary={handleUpdateBoundary}
                            onDeleteMark={handleDeleteMark}
                        />

                        <CourseDesignerEvents
                            selectedTool={selectedTool}
                            drawingMode={drawingMode}
                            onAddMark={handleAddMark}
                        />
                        <WindArrowLayer boundary={raceState.course.courseBoundary} windDir={raceState.wind.direction} />
                    </MapContainer>

                    {/* Playback Scrubber Overlay */}
                    <AnimatePresence>
                        {activeTab === 'OVERVIEW' && (
                            <motion.div
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: 20 }}
                                className="absolute bottom-6 left-1/2 -translate-x-1/2 w-[600px] z-[1000] bg-regatta-dark/90 backdrop-blur-xl border border-white/10 rounded-3xl p-5 shadow-2xl flex flex-col gap-4"
                                style={{ pointerEvents: 'auto' }}
                            >
                                <div className="flex justify-between items-center">
                                    <div className="text-[10px] font-black text-accent-blue uppercase tracking-widest flex items-center gap-2">
                                        <Monitor size={14} /> Historical Playback Timeline
                                    </div>
                                    <div className="text-[10px] font-mono font-bold text-gray-400 bg-white/5 border border-white/10 px-2 py-1 rounded-lg">
                                        {playbackTime ? new Date(playbackTime).toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' }) : 'Live Feed Active'}
                                    </div>
                                </div>
                                <div className="flex items-center gap-4">
                                    <button
                                        onClick={() => setPlaybackTime(null)}
                                        className={`p-2.5 rounded-xl transition-all ${!playbackTime ? 'bg-accent-cyan text-white shadow-[0_0_15px_rgba(6,182,212,0.4)]' : 'bg-white/5 text-gray-400 hover:text-white'}`}
                                        title="Return to Live"
                                    >
                                        <Play size={12} className={!playbackTime ? 'fill-current' : ''} />
                                    </button>
                                    <input
                                        type="range"
                                        min={Date.now() - 30 * 60000}
                                        max={Date.now()}
                                        value={playbackTime || Date.now()}
                                        onChange={(e) => setPlaybackTime(Number(e.target.value))}
                                        className="flex-1 h-1.5 bg-white/10 rounded-lg appearance-none cursor-pointer"
                                        style={{ accentColor: '#06b6d4' }}
                                        disabled={!raceState.fleetHistory || Object.keys(raceState.fleetHistory).length === 0}
                                    />
                                    <div className="text-[8px] font-black text-gray-600 uppercase tracking-widest">
                                        -30m
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>

                    {/* Vignette Overlay for Focus */}
                    <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(circle_at_center,transparent_20%,rgba(15,23,42,0.6)_100%)]" />
                </div>

                {/* Floating HUD Container (Anchored below header) */}
                <div className="absolute top-32 bottom-0 left-0 right-0 z-10 p-12 flex gap-10 pointer-events-none">

                    {/* Left Wing Panels */}
                    <AnimatePresence>
                        {
                            activeTab === 'OVERVIEW' && (
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
                                                <div className="flex items-center justify-between gap-4">
                                                    <div className="flex-1">
                                                        <div className="text-[9px] font-bold text-gray-500 uppercase tracking-widest mb-1">Speed (kts)</div>
                                                        <div className="flex items-end gap-1">
                                                            <input
                                                                type="number"
                                                                min={0} max={99} step={0.5}
                                                                value={raceState.wind.speed}
                                                                onChange={e => handleUpdateWind({ ...raceState.wind, speed: parseFloat(e.target.value) || 0 })}
                                                                className="bg-transparent text-3xl font-black italic tracking-tighter text-white w-20 outline-none border-b-2 border-white/20 focus:border-accent-blue transition-colors"
                                                            />
                                                            <span className="text-xs text-gray-500 mb-1">kts</span>
                                                        </div>
                                                    </div>
                                                    <div className="flex-1 text-right">
                                                        <div className="text-[9px] font-bold text-gray-500 uppercase tracking-widest mb-1">Direction (°)</div>
                                                        <div className="flex items-end gap-1 justify-end">
                                                            <input
                                                                type="number"
                                                                min={0} max={359} step={1}
                                                                value={raceState.wind.direction}
                                                                onChange={e => {
                                                                    let v = parseInt(e.target.value) || 0;
                                                                    if (v < 0) v = 359;
                                                                    if (v > 359) v = 0;
                                                                    handleUpdateWind({ ...raceState.wind, direction: v });
                                                                }}
                                                                className="bg-transparent text-3xl font-black italic tracking-tighter text-accent-cyan w-20 outline-none border-b-2 border-white/20 focus:border-accent-cyan transition-colors text-right"
                                                            />
                                                            <span className="text-xs text-gray-500 mb-1">°</span>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>

                                            {/* Race Progress Card */}
                                            <div className="p-5 rounded-2xl bg-white/5 border border-white/5">
                                                <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Live Race Intelligence</div>
                                                <div className="space-y-4">
                                                    <div className="flex items-center justify-between">
                                                        <span className="text-[10px] font-bold text-gray-500 uppercase">Status</span>
                                                        <span className={`text-[10px] font-black uppercase ${raceState.status === 'RACING' ? 'text-accent-green'
                                                            : ['WARNING', 'PREPARATORY', 'ONE_MINUTE'].includes(raceState.status) ? 'text-accent-cyan'
                                                                : ['POSTPONED', 'INDIVIDUAL_RECALL', 'GENERAL_RECALL'].includes(raceState.status) ? 'text-amber-400'
                                                                    : raceState.status === 'ABANDONED' ? 'text-red-400'
                                                                        : 'text-gray-400'
                                                            }`}>{raceState.status.replace(/_/g, ' ')}</span>
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
                                                    onClick={() => setActiveTab('PROCEDURE')}
                                                    className="w-full py-4 bg-accent-blue hover:bg-blue-600 text-white rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                                >
                                                    Launch Procedure
                                                </button>
                                                <button
                                                    onClick={() => setActiveTab('ARCHITECT')}
                                                    className="w-full py-4 bg-accent-cyan/10 hover:bg-accent-cyan/20 border border-accent-cyan/30 text-accent-cyan rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                                >
                                                    Procedure Editor
                                                </button>
                                                <button
                                                    onClick={() => setActiveTab('DESIGNER')}
                                                    className="w-full py-4 bg-white/5 hover:bg-white/10 border border-white/10 text-white rounded-xl font-black uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-3 transition-all"
                                                >
                                                    Course Designer
                                                </button>
                                            </div>
                                        </div>
                                    </GlassPanel>
                                </motion.div>
                            )
                        }

                        {
                            activeTab === 'FLEET' && (
                                <FleetControl key="fleet" engine={engine} raceState={raceState} />
                            )
                        }

                        {
                            activeTab === 'DESIGNER' && (
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
                                                <DesignerTool
                                                    label="Measure (Ruler)"
                                                    active={selectedTool === 'MEASURE'}
                                                    onClick={() => {
                                                        setSelectedTool(selectedTool === 'MEASURE' ? null : 'MEASURE');
                                                        setDrawingMode(false);
                                                        setMeasurePoints([]); // clear on tool click
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

                                            <button
                                                onClick={() => setSyncDrag(!syncDrag)}
                                                className={`w-full py-3 mb-2 rounded-xl border flex items-center justify-center gap-2 transition-all ${syncDrag ? 'bg-accent-blue/20 border-accent-blue/50 text-accent-blue' : 'bg-white/5 border-white/10 text-gray-500 hover:bg-white/10 hover:text-white'}`}
                                            >
                                                <span className="text-[10px] font-black uppercase tracking-widest">{syncDrag ? 'Linked Drag: ON (Translates Lines)' : 'Linked Drag: OFF (Pivots Marks)'}</span>
                                            </button>

                                            <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4 border-b border-white/5 pb-2 mt-4">Automated Generators</div>
                                            <div className="grid grid-cols-2 gap-3 mb-6">
                                                <button
                                                    onClick={handleGenerateWindwardLeeward}
                                                    className="p-4 rounded-xl border bg-white/5 border-white/10 text-white shadow-lg hover:shadow-accent-blue/20 hover:border-accent-blue/50 flex flex-col items-center justify-center gap-2 transition-all relative overflow-hidden group"
                                                >
                                                    <div className="absolute inset-0 bg-gradient-to-br from-accent-blue/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                                                    <span className="text-[10px] font-black uppercase tracking-widest text-center leading-tight">W/L Course</span>
                                                </button>
                                                <button
                                                    onClick={handleGenerateOlympicTriangle}
                                                    className="p-4 rounded-xl border bg-white/5 border-white/10 text-white shadow-lg hover:shadow-accent-cyan/20 hover:border-accent-cyan/50 flex flex-col items-center justify-center gap-2 transition-all relative overflow-hidden group"
                                                >
                                                    <div className="absolute inset-0 bg-gradient-to-br from-accent-cyan/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                                                    <span className="text-[10px] font-black uppercase tracking-widest text-center leading-tight">Olympic<br />Triangle</span>
                                                </button>
                                            </div>

                                            <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4 border-b border-white/5 pb-2">Active Buoys ({raceState.course.marks.length})</div>

                                            {raceState.course.marks.map((m) => (
                                                <div key={m.id} className="p-4 rounded-xl bg-white/5 border border-white/5 hover:border-accent-blue/30 transition-all group">
                                                    <div className="flex items-center justify-between pointer-events-auto">
                                                        <div className="flex items-center gap-3">
                                                            <div className="w-8 h-8 rounded-lg bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden">
                                                                <div
                                                                    className="w-3 h-3 rounded-full shadow-[0_0_10px_rgba(255,255,255,0.2)]"
                                                                    style={{ backgroundColor: m.color === 'yellow' ? '#fbbf24' : m.color === 'orange' ? '#f97316' : m.color === 'red' ? '#ef4444' : m.color === 'green' ? '#22c55e' : '#3b82f6' }}
                                                                />
                                                            </div>
                                                            <div>
                                                                <div className="text-[10px] font-black uppercase tracking-widest text-white">{m.name}</div>
                                                                <div className="text-[8px] font-bold text-gray-500 uppercase tracking-widest">{m.type}</div>
                                                            </div>
                                                        </div>
                                                        <div className="flex items-center gap-4">
                                                            <button
                                                                onClick={() => handleDeleteMark(m.id)}
                                                                className="p-2 hover:bg-accent-red/10 border border-transparent hover:border-accent-red/30 text-gray-500 hover:text-accent-red rounded-lg transition-all"
                                                            >
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>
                                                    </div>
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

                                            <button
                                                onClick={() => {
                                                    engine?.emit('update-course', raceState.course);
                                                    setShowSaveSuccess(true);
                                                    setTimeout(() => setShowSaveSuccess(false), 2000);
                                                }}
                                                className="w-full relative py-4 bg-accent-blue text-white rounded-xl text-[10px] font-black uppercase tracking-[0.25em] shadow-lg shadow-accent-blue/20 hover:shadow-accent-blue/40 transition-all overflow-hidden"
                                            >
                                                <div className={`absolute inset-0 bg-accent-green flex items-center justify-center transition-transform duration-500 ${showSaveSuccess ? 'translate-y-0' : 'translate-y-full'}`}>
                                                    SYNC SUCCESSFUL
                                                </div>
                                                <span className={`${showSaveSuccess ? 'opacity-0' : 'opacity-100'} transition-opacity`}>Sync Course Data</span>
                                            </button>
                                        </div>
                                    </GlassPanel>
                                </motion.div>
                            )
                        }

                        {
                            activeTab === 'PROCEDURE' && (
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
                                                socket={engine.socket as any}
                                                raceStatus={raceState.status}
                                                sequenceTimeRemaining={raceState.sequenceTimeRemaining}
                                                currentFlags={raceState.currentFlags}
                                                currentEvent={raceState.currentEvent}
                                                prepFlag={raceState.prepFlag}
                                                currentProcedure={raceState.currentProcedure}
                                                currentNodeId={raceState.currentNodeId}
                                                waitingForTrigger={raceState.waitingForTrigger}
                                                actionLabel={raceState.actionLabel}
                                                activeFlightId={raceState.activeFlightId}
                                                fleetMode={raceState.fleetSettings?.mode}
                                                flights={Object.values(raceState.flights || {}).sort((a: any, b: any) => a.flightNumber - b.flightNumber)}
                                            />
                                        </ErrorBoundary>
                                    </GlassPanel>
                                </motion.div>
                            )
                        }

                        {
                            activeTab === 'SETTINGS' && (
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
                                                        engine?.emit('update-default-location', { lat: center.lat, lon: center.lng, zoom: z });
                                                        setShowSaveSuccess(true);
                                                        setTimeout(() => setShowSaveSuccess(false), 2000);
                                                    }}
                                                    className={`w-full py-4 border rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all ${showSaveSuccess ? 'bg-accent-green/20 border-accent-green text-accent-green' : 'bg-accent-blue/10 hover:bg-accent-blue/20 border-accent-blue/50 text-accent-blue'}`}
                                                >
                                                    {showSaveSuccess ? 'Location Locked!' : 'Lock Current Map Location'}
                                                </button>
                                            </div>

                                            <div className="p-6 rounded-2xl bg-white/5 border border-white/10">
                                                <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4">Data Management</div>
                                                <div className="flex flex-col gap-3">
                                                    <button
                                                        onClick={handleExportMarkSetBot}
                                                        className="w-full py-4 bg-accent-blue/10 hover:bg-accent-blue/20 border border-accent-blue/50 text-accent-blue rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all"
                                                    >
                                                        Export to MarkSetBot (JSON)
                                                    </button>
                                                    <button
                                                        onClick={handleClearAll}
                                                        className="w-full py-4 bg-accent-red/10 hover:bg-accent-red/20 border border-accent-red/50 text-accent-red rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all"
                                                    >
                                                        Wipe All Course Data
                                                    </button>
                                                </div>
                                            </div>
                                        </div>
                                    </GlassPanel>
                                </motion.div>
                            )
                        }
                        {
                            activeTab === 'LOGS' && (
                                <motion.div
                                    key="logs"
                                    initial={{ x: -20, opacity: 0 }}
                                    animate={{ x: 0, opacity: 1 }}
                                    exit={{ x: -20, opacity: 0 }}
                                    className="flex-1 h-full flex flex-col pointer-events-auto min-w-[1000px]"
                                >
                                    <LogView logs={raceState.logs} onUpdateLog={handleUpdateLog} />
                                </motion.div>
                            )
                        }
                    </AnimatePresence>

                    {/* Spacer */}
                    <div className="flex-1" />

                    {/* Right Wing (Always Visible) */}
                    <div className="w-96 flex flex-col gap-6">
                        <WindControl
                            wind={raceState.wind}
                            onChange={handleUpdateWind}
                            onFetchWeather={handleFetchWeather}
                            isFetching={isFetchingWeather}
                        />

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
                                                    if (engine) {
                                                        engine.emit('kill-tracker', id);
                                                    } else {
                                                        console.error('[UI] Engine connection not found');
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
                                                if (engine) {
                                                    engine.emit('clear-fleet');
                                                } else {
                                                    console.error('[UI] Engine connection not found');
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
                    </div >

                </div >

                {/* Procedure Editor Overlay (Outside regular HUD flow) */}
                <AnimatePresence>
                    {
                        activeTab === 'SIMULATOR' && (
                            <UWBSimulator />
                        )
                    }
                    {
                        activeTab === 'ARCHITECT' && (
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
                                        onClick={() => setActiveTab('PROCEDURE')}
                                        className="px-8 py-3 bg-white/5 hover:bg-accent-red/20 border border-white/10 hover:border-accent-red/50 text-white hover:text-accent-red rounded-xl text-[10px] font-black uppercase tracking-widest transition-all shadow-lg"
                                    >
                                        Close Architect
                                    </button>
                                </div>
                                <div className="flex-1 relative border-t border-white/5 bg-slate-900/50">
                                    <div className="absolute top-2 left-6 z-[110] text-[8px] font-black text-white/20 uppercase tracking-[0.5em] pointer-events-none">Logic Canvas Active</div>
                                    <ErrorBoundary>
                                        <ProcedureEditor currentProcedure={raceState.currentProcedure} socket={engine.socket as any} />
                                    </ErrorBoundary>
                                </div>
                            </motion.div>
                        )
                    }
                </AnimatePresence >
            </div >
        </div >
    )
}
