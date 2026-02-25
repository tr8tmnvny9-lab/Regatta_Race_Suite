import { useState, useEffect, useRef } from 'react'
import { MapContainer, TileLayer, Polyline, Marker, useMapEvents, CircleMarker } from 'react-leaflet'
import L from 'leaflet'
import { RegattaEngine } from '@regatta/core'
import {
    Zap, MousePointer2, Trash2, Play, Square,
    Activity, Clock, ChevronRight,
    Shield, Globe
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

const BOAT_ICON = (heading: number) => L.divIcon({
    className: 'boat-marker',
    html: `
        <div style="transform: rotate(${heading}deg); transition: transform 0.1s linear;">
            <svg width="24" height="40" viewBox="0 0 24 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2C12 2 4 12 4 24C4 32.8366 7.58172 38 12 38C16.4183 38 20 32.8366 20 24C20 12 12 2 12 2Z" fill="#3B82F6" fill-opacity="0.9" stroke="white" stroke-width="2"/>
                <path d="M12 6V20" stroke="white" stroke-width="2" stroke-linecap="round"/>
            </svg>
        </div>
    `,
    iconSize: [24, 40],
    iconAnchor: [12, 38]
});

const MapController = ({ onMapClick }: { onMapClick: (e: any) => void }) => {
    useMapEvents({
        click: onMapClick
    });
    return null;
};

export default function TrackerMock() {
    const params = new URLSearchParams(window.location.search);
    const boatId = params.get('boatId') || `BOAT-${Math.random().toString(36).substring(7).toUpperCase()}`;

    const [engine, setEngine] = useState<RegattaEngine | null>(null);
    const [status, setStatus] = useState<'IDLE' | 'LIVE' | 'TERMINATED'>('IDLE');
    const [pos, setPos] = useState({ lat: 59.3293, lon: 18.0686 });
    const [heading, setHeading] = useState(124);
    const [speed, setSpeed] = useState(0);
    const [speedSetting, setSpeedSetting] = useState(8);
    const [dtl] = useState(542);
    const [path, setPath] = useState<[number, number][]>([]);
    const [isDrawing, setIsDrawing] = useState(false);
    const [isSimulating, setIsSimulating] = useState(false);
    const [pathProgress, setPathProgress] = useState(0);
    const [raceState, setRaceState] = useState<any>(null);

    const isTerminated = useRef(false);

    // Socket Connection
    useEffect(() => {
        const eng = new RegattaEngine('http://localhost:3001', 'tracker');
        setEngine(eng);
        const s = eng.socket;
        if (!s) return;

        s.on('connect', () => {
            if (isTerminated.current) {
                s.disconnect();
                return;
            }
            s.emit('register', { type: 'tracker', boatId });
            setStatus('LIVE');
        });

        eng.onStateChange((state) => {
            setRaceState(state);
            if (state.boats && state.boats[boatId]) {
                const b = state.boats[boatId];
                if (b.simulationPath) {
                    setPath(b.simulationPath.map((p: any) => [p.lat, p.lon]));
                }
                if (b.isSimulating !== undefined) setIsSimulating(b.isSimulating);
                if (b.speedSetting !== undefined) setSpeedSetting(b.speedSetting);
                if (b.pathProgress !== undefined) setPathProgress(b.pathProgress);
                // Only update pos if not simulating locally to avoid fighting the interpolator
                if (b.pos && !isSimulating) setPos({ lat: b.pos.lat, lon: b.pos.lon });
            }
        });

        s.on('kill-simulation', (payload: any) => {
            const targetId = typeof payload === 'string' ? payload : payload.id;
            if (targetId === boatId || targetId === 'all') {
                isTerminated.current = true;
                setIsSimulating(false);
                setStatus('TERMINATED');
                s.disconnect();
            }
        });

        return () => {
            s?.disconnect();
        };
    }, [boatId]);

    const watchId = useRef<number | null>(null);
    const [gpsActive, setGpsActive] = useState(false);

    const toggleGPS = () => {
        if (gpsActive) {
            if (watchId.current !== null) navigator.geolocation.clearWatch(watchId.current);
            setGpsActive(false);
            if (status === 'LIVE' && !isSimulating) {
                setSpeed(0);
            }
        } else {
            if ("geolocation" in navigator) {
                watchId.current = navigator.geolocation.watchPosition(
                    (position) => {
                        setPos({ lat: position.coords.latitude, lon: position.coords.longitude });
                        if (position.coords.heading !== null) setHeading(position.coords.heading);
                        if (position.coords.speed !== null) setSpeed(position.coords.speed * 1.94384); // m/s to knots
                        setIsSimulating(false);
                        setGpsActive(true);

                        // Clear manual path to avoid visual confusion
                        setPath([]);
                        setPathProgress(0);
                    },
                    (error) => {
                        console.error(error);
                        alert("Geolocation error: " + error.message);
                        setGpsActive(false);
                    },
                    { enableHighAccuracy: true, maximumAge: 0, timeout: 5000 }
                );
            } else {
                alert("Geolocation is not supported by this browser.");
            }
        }
    };

    useEffect(() => {
        return () => {
            if (watchId.current !== null) navigator.geolocation.clearWatch(watchId.current);
        }
    }, [])

    // Path Simulation Logic
    useEffect(() => {
        if (!isSimulating || path.length < 2) return;

        const interval = setInterval(() => {
            let totalDist = 0;
            for (let i = 0; i < path.length - 1; i++) {
                const p1 = L.latLng(path[i][0], path[i][1]);
                const p2 = L.latLng(path[i + 1][0], path[i + 1][1]);
                totalDist += p1.distanceTo(p2);
            }

            if (totalDist > 0) {
                const speedMps = speedSetting * 0.514444;
                const distThisTick = speedMps * 0.1;
                const progressIncrement = distThisTick / totalDist;

                setPathProgress(prev => {
                    const next = prev + progressIncrement;
                    return next > 1 ? 0 : next;
                });
            }
        }, 100);

        return () => clearInterval(interval);
    }, [isSimulating, path, speedSetting]);

    // Interpolate Position
    useEffect(() => {
        if (!isSimulating || path.length < 2) return;

        const numSegments = path.length - 1;
        const segmentIdx = Math.min(Math.floor(pathProgress * numSegments), numSegments - 1);
        const segmentProgress = (pathProgress * numSegments) % 1;

        const p1 = path[segmentIdx];
        const p2 = path[segmentIdx + 1];

        const newLat = p1[0] + (p2[0] - p1[0]) * segmentProgress;
        const newLon = p1[1] + (p2[1] - p1[1]) * segmentProgress;

        const dy = p2[0] - p1[0];
        const dx = Math.cos(p1[0] * Math.PI / 180) * (p2[1] - p1[1]);
        const angle = Math.atan2(dx, dy) * 180 / Math.PI;

        setPos({ lat: newLat, lon: newLon });
        setHeading(angle);
        setSpeed(speedSetting);
    }, [pathProgress, isSimulating, path, speedSetting]);

    // Emit Updates
    useEffect(() => {
        if (engine && engine.socket && status === 'LIVE') {
            engine.socket.emit('track-update', {
                boatId,
                pos,
                imu: { heading, roll: 0, pitch: 0 },
                velocity: { speed, dir: heading },
                dtl,
                timestamp: Date.now(),
                simulationPath: path.map(p => ({ lat: p[0], lon: p[1] })),
                isSimulating,
                speedSetting,
                pathProgress
            });
        }
    }, [engine, status, boatId, pos, heading, speed, dtl, path, isSimulating, speedSetting, pathProgress]);

    const handleMapClick = (e: any) => {
        if (!isDrawing) return;
        setPath(prev => [...prev, [e.latlng.lat, e.latlng.lng]]);
    };

    if (status === 'TERMINATED') {
        return (
            <div className="h-screen w-screen bg-black flex flex-col items-center justify-center p-12 text-center font-['Outfit']">
                <div className="w-24 h-24 bg-red-500/10 rounded-3xl flex items-center justify-center border border-red-500/20 mb-8">
                    <Shield className="text-red-500" size={40} />
                </div>
                <h1 className="text-4xl font-black italic tracking-tighter uppercase mb-2 text-white">Simulation Terminated</h1>
                <p className="text-gray-500 font-bold uppercase tracking-widest text-[10px]">Access Revoked by Race Committee</p>
                <button onClick={() => window.close()} className="mt-10 px-8 py-4 bg-white/5 border border-white/10 rounded-2xl text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all">Close Instance</button>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-[#050507] text-white flex font-['Outfit'] select-none overflow-hidden uppercase">
            {/* Sidebar */}
            <aside className="w-80 border-r border-white/5 bg-black/40 backdrop-blur-xl flex flex-col p-6 z-20">
                <div className="flex items-center gap-3 mb-10">
                    <div className="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-500/20">
                        <Zap className="text-white fill-current" size={20} />
                    </div>
                    <h2 className="text-lg font-black italic tracking-tighter leading-none">Augmented <span className="text-blue-500">Tracker</span></h2>
                </div>

                <div className="flex-1 space-y-8 overflow-y-auto pr-2 custom-scrollbar">
                    <div className="space-y-4">
                        <div className="text-[10px] font-black text-gray-500 tracking-[0.2em] flex items-center gap-2"><Globe size={12} className="text-green-500" /> Real-World Tracker</div>
                        <button
                            onClick={toggleGPS}
                            className={`w-full py-5 rounded-3xl flex items-center justify-center gap-3 border transition-all ${gpsActive ? 'bg-green-600 border-green-400 text-white shadow-[0_0_20px_rgba(22,163,74,0.4)]' : 'bg-white/5 border-white/10 text-gray-400 hover:bg-white/10'}`}
                        >
                            {gpsActive ? <Square size={18} fill="currentColor" /> : <Shield size={18} className="text-green-500" />}
                            <span className="text-[11px] font-black tracking-widest">{gpsActive ? 'Disable Live GPS' : 'Enable HTML5 GPS Sensor'}</span>
                        </button>
                    </div>

                    <div className="h-px w-full bg-white/5 my-6" />

                    <div className="space-y-4">
                        <div className="text-[10px] font-black text-gray-500 tracking-[0.2em]">Manual Path Architect</div>
                        <button
                            onClick={() => {
                                setIsDrawing(!isDrawing);
                                if (!isDrawing) setIsSimulating(false);
                            }}
                            className={`w-full py-4 rounded-2xl flex items-center justify-center gap-3 border transition-all ${isDrawing ? 'bg-blue-600 border-blue-400 text-white shadow-lg' : 'bg-white/5 border-white/10 text-gray-400 hover:bg-white/10'}`}
                        >
                            <MousePointer2 size={16} />
                            <span className="text-[11px] font-black tracking-widest">{isDrawing ? 'Finish Drawing' : 'Plot Waypoints'}</span>
                        </button>
                        <button
                            onClick={() => { setPath([]); setPathProgress(0); setIsSimulating(false); }}
                            className="w-full py-3 rounded-2xl flex items-center justify-center gap-3 bg-white/5 border border-white/10 text-gray-400 hover:bg-red-500/10 hover:border-red-500/30 hover:text-red-500 transition-all"
                        >
                            <Trash2 size={14} />
                            <span className="text-[10px] font-black tracking-widest">Clear Path</span>
                        </button>
                    </div>

                    <div className="space-y-4">
                        <div className="text-[10px] font-black text-gray-500 tracking-[0.2em]">Simulation Engine</div>
                        <div className="p-4 rounded-2xl bg-white/5 border border-white/5 space-y-3">
                            <div className="flex justify-between items-center">
                                <span className="text-[9px] font-black text-gray-400 tracking-widest">Boat Speed</span>
                                <span className="text-sm font-black italic text-blue-400">{speedSetting}<span className="text-[8px] not-italic ml-1">KTS</span></span>
                            </div>
                            <input
                                type="range"
                                min="0.5"
                                max="30"
                                step="0.5"
                                value={speedSetting}
                                onChange={(e) => setSpeedSetting(parseFloat(e.target.value))}
                                className="w-full h-1 bg-white/10 rounded-full appearance-none cursor-pointer accent-blue-500"
                            />
                        </div>

                        <button
                            onClick={() => {
                                if (path.length > 1) {
                                    setIsSimulating(!isSimulating);
                                    setIsDrawing(false);
                                }
                            }}
                            disabled={path.length < 2}
                            className={`w-full py-5 rounded-3xl flex items-center justify-center gap-3 border transition-all ${isSimulating ? 'bg-green-600 border-green-400 text-white shadow-lg' : 'bg-white/5 border-white/10 text-gray-500 disabled:opacity-20'}`}
                        >
                            {isSimulating ? <Square size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" />}
                            <span className="text-xs font-black tracking-widest">{isSimulating ? 'Kill Simulation' : 'Launch Path-Follow'}</span>
                        </button>
                    </div>

                    <div className="p-6 rounded-3xl bg-blue-600/5 border border-blue-500/10 space-y-4">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
                                <Activity className="text-blue-400" size={16} />
                            </div>
                            <span className="text-[10px] font-black tracking-[0.2em] text-blue-400">Path Intelligence</span>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <div className="text-[9px] font-bold text-gray-500 tracking-widest mb-1">LOOP LENGTH</div>
                                <div className="text-lg font-black italic tracking-tighter text-gray-300">
                                    {(path.reduce((acc, p, i) => i === 0 ? 0 : acc + L.latLng(p[0], p[1]).distanceTo(L.latLng(path[i - 1][0], path[i - 1][1])), 0) / 1852).toFixed(2)}
                                    <span className="text-[10px] not-italic ml-1 opacity-50 text-gray-400">NM</span>
                                </div>
                            </div>
                            <div>
                                <div className="text-[9px] font-bold text-gray-500 tracking-widest mb-1">POINT COUNT</div>
                                <div className="text-lg font-black italic tracking-tighter text-gray-300">{path.length} <span className="text-[10px] not-italic ml-1 opacity-50 text-gray-400">NODES</span></div>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="pt-6 border-t border-white/5 mt-auto">
                    <div className="flex items-center gap-4 p-4 rounded-2xl bg-white/5 border border-white/5">
                        <div className="w-10 h-10 rounded-xl bg-blue-500/20 flex items-center justify-center">
                            {status === 'LIVE' ? <div className="w-2 h-2 rounded-full bg-blue-500 animate-pulse shadow-[0_0_10px_#3b82f6]" /> : <Activity size={18} className="text-gray-600" />}
                        </div>
                        <div>
                            <div className="text-[11px] font-black tracking-tight text-white">{boatId}</div>
                            <div className={`text-[8px] font-black tracking-widest ${status === 'LIVE' ? 'text-blue-500' : 'text-gray-600'}`}>
                                {status === 'LIVE' ? 'SYSTEMS ONLINE' : 'OFFLINE'}
                            </div>
                        </div>
                    </div>
                </div>
            </aside>

            {/* Map Area */}
            <main className="flex-1 relative bg-regatta-dark">
                <MapContainer center={[pos.lat, pos.lon]} zoom={15} zoomControl={false} className="w-full h-full grayscale-[0.2] contrast-[1.1]">
                    <TileLayer url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" />
                    <MapController onMapClick={handleMapClick} />

                    {path.length > 0 && (
                        <Polyline positions={path} color="#3b82f6" weight={3} opacity={0.6} dashArray="10, 10" />
                    )}

                    {path.map((p, i) => (
                        <CircleMarker key={i} center={p} radius={4} fillOpacity={0.8} fillColor="#3b82f6" stroke={false} />
                    ))}

                    <Marker position={[pos.lat, pos.lon]} icon={BOAT_ICON(heading)} />

                    {raceState?.course?.marks?.map((m: any) => (
                        <CircleMarker key={m.id} center={[m.pos.lat, m.pos.lon]} radius={6} color="white" weight={2} fillOpacity={1} fillColor="#ef4444" />
                    ))}
                </MapContainer>

                {/* Overlays */}
                <div className="absolute inset-x-0 bottom-0 p-8 z-10 pointer-events-none flex flex-col gap-4">
                    <div className="flex items-end justify-between">
                        <div className="flex gap-4 pointer-events-auto">
                            <div className="glass px-6 py-4 rounded-2xl border border-white/5">
                                <div className="text-[10px] text-gray-500 font-black tracking-widest mb-0.5">SPEED OVER GROUND</div>
                                <div className="text-2xl font-black italic tracking-tighter tabular-nums text-white">{speed.toFixed(1)}<span className="text-[10px] not-italic ml-0.5 opacity-50">KTS</span></div>
                            </div>
                            <div className="glass px-6 py-4 rounded-2xl border border-white/5">
                                <div className="text-[10px] text-gray-500 font-black tracking-widest mb-0.5">HEADING</div>
                                <div className="text-2xl font-black italic tracking-tighter tabular-nums text-white">{Math.round(heading)}°</div>
                            </div>
                            <div className="glass px-6 py-4 rounded-2xl border border-white/5">
                                <div className="text-[10px] text-gray-500 font-black tracking-widest mb-0.5">DTL</div>
                                <div className="text-2xl font-black italic tracking-tighter tabular-nums text-blue-500">{dtl.toFixed(1)}<span className="text-[10px] not-italic ml-0.5 opacity-50">M</span></div>
                            </div>
                        </div>

                        <div className="flex-1" />

                        {/* Race Status HUD */}
                        <AnimatePresence>
                            {raceState && raceState.status === 'PRE_START' && (
                                <motion.div
                                    initial={{ y: 50, opacity: 0 }}
                                    animate={{ y: 0, opacity: 1 }}
                                    className="bg-blue-600 rounded-[30px] p-6 flex items-center gap-6 shadow-2xl ring-1 ring-white/20 self-center w-full max-w-lg mb-4 pointer-events-auto"
                                >
                                    <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center">
                                        <Clock className="text-white" size={24} />
                                    </div>
                                    <div className="flex-1 text-white">
                                        <div className="flex justify-between items-end mb-1">
                                            <div className="text-[11px] font-bold tracking-[0.2em] opacity-80">Sequence Running</div>
                                            <div className="text-2xl font-black tabular-nums italic tracking-tighter">
                                                {raceState.sequenceTimeRemaining ? `${Math.floor(raceState.sequenceTimeRemaining / 60)}:${(raceState.sequenceTimeRemaining % 60).toString().padStart(2, '0')}` : '0:00'}
                                            </div>
                                        </div>
                                        <div className="h-2 bg-black/20 rounded-full overflow-hidden">
                                            <motion.div
                                                initial={{ width: 0 }}
                                                animate={{ width: `${((raceState.sequenceTimeRemaining || 0) / 300) * 100}%` }}
                                                className="h-full bg-white rounded-full"
                                            />
                                        </div>
                                        <div className="mt-2 text-[10px] font-black tracking-widest flex items-center gap-2">
                                            <ChevronRight size={14} className="opacity-50" /> {raceState.currentSequence?.event || 'PRE-START'}
                                        </div>
                                    </div>
                                </motion.div>
                            )}
                        </AnimatePresence>

                        {isDrawing && (
                            <div className="bg-amber-500/20 border border-amber-500/50 backdrop-blur-md px-6 py-3 rounded-xl self-center animate-pulse pointer-events-auto">
                                <span className="text-[10px] font-black text-amber-500 tracking-[0.3em]">Drawing Mode Active — Plot waypoints on map</span>
                            </div>
                        )}
                    </div>
                </div>
            </main>
        </div>
    );
}
