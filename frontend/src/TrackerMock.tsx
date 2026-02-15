import { useState, useEffect, useRef } from 'react'
import { io, Socket } from 'socket.io-client'
import { Zap, Clock, ChevronRight, Play, Square, MousePointer2, Trash2, RotateCcw } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapContainer, TileLayer, Polyline, Marker, useMapEvents, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// Custom Boat Icon for the Tracker Map
const TRACKER_BOAT_ICON = (heading: number) => L.divIcon({
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
    iconAnchor: [12, 38]
});

function MapEvents({ onMapClick }: { onMapClick: (e: any) => void }) {
    useMapEvents({
        click: onMapClick,
    });
    return null;
}

function MapController({ raceState }: { raceState: any }) {
    const map = useMap();
    useEffect(() => {
        if (raceState?.defaultLocation) {
            map.setView([raceState.defaultLocation.lat, raceState.defaultLocation.lon], raceState.defaultLocation.zoom || 15);
        } else if (raceState?.course?.courseBoundary?.length > 0) {
            const bounds = L.latLngBounds(raceState.course.courseBoundary.map((p: any) => [p.lat, p.lon]));
            map.fitBounds(bounds, { padding: [50, 50] });
        }
    }, [raceState, map]);
    return null;
}

export default function TrackerMock() {
    const [socket, setSocket] = useState<Socket | null>(null)
    const [boatId] = useState(() => {
        const params = new URLSearchParams(window.location.search);
        return params.get('boatId') || 'BOAT-' + Math.random().toString(36).substr(2, 4).toUpperCase();
    })
    const [status, setStatus] = useState('CONNECTING')
    const [pos, setPos] = useState({ lat: 59.3293, lon: 18.0686 })
    const [speed, setSpeed] = useState(0)
    const [dtl, setDtl] = useState(50)
    const [raceState, setRaceState] = useState<any>(null)

    // Augmented Tracker State
    const [path, setPath] = useState<[number, number][]>([])
    const [isDrawing, setIsDrawing] = useState(false)
    const [isSimulating, setIsSimulating] = useState(false)
    const [pathProgress, setPathProgress] = useState(0) // 0 to 1 along the path
    const [heading, setHeading] = useState(124)

    const isTerminated = useRef(false);

    useEffect(() => {
        const s = io('http://localhost:3001')
        setSocket(s)

        s.on('connect', () => {
            if (isTerminated.current) {
                s.disconnect();
                return;
            }
            s.emit('register', { type: 'tracker', boatId })
            setStatus('LIVE')
        })

        s.on('init-state', (data) => {
            setRaceState(data);
            if (data.defaultLocation && pos.lat === 59.3293) {
                setPos({ lat: data.defaultLocation.lat, lon: data.defaultLocation.lon });
            }
        });

        s.on('course-updated', (course) => {
            setRaceState((prev: any) => ({ ...prev, course }));
        });

        s.on('sequence-update', (data) => setRaceState((prev: any) => ({ ...prev, ...data })))

        s.on('kill-simulation', (targetId) => {
            if (targetId === boatId || targetId === 'all') {
                console.log('Simulation terminated by management');
                isTerminated.current = true;
                setIsSimulating(false);
                setIsDrawing(false);
                setPath([]);
                setStatus('TERMINATED');
                s.disconnect();
            }
        });

        // Standard Random Simulation (Fallback if no path)
        const interval = setInterval(() => {
            if (isSimulating && path.length > 1) {
                // Path following logic
                setPathProgress(prev => {
                    const next = prev + 0.005; // Adjust speed
                    return next > 1 ? 0 : next;
                });
            } else if (!isSimulating) {
                setPos(prev => ({
                    lat: prev.lat + (Math.random() - 0.5) * 0.0001,
                    lon: prev.lon + (Math.random() - 0.5) * 0.0001
                }))
                setSpeed(prev => Math.max(0, prev + (Math.random() - 0.4) * 0.2))
                setDtl(prev => Math.max(0, prev - (Math.random() * 0.5)))
            }
        }, 1000)

        return () => {
            clearInterval(interval)
            s.close()
        }
    }, [boatId])

    // Path Follower Interpolation
    useEffect(() => {
        if (isSimulating && path.length > 1) {
            const numSegments = path.length - 1;
            const segmentIdx = Math.min(Math.floor(pathProgress * numSegments), numSegments - 1);
            const segmentProgress = (pathProgress * numSegments) % 1;

            const p1 = path[segmentIdx];
            const p2 = path[segmentIdx + 1];

            const newLat = p1[0] + (p2[0] - p1[0]) * segmentProgress;
            const newLon = p1[1] + (p2[1] - p1[1]) * segmentProgress;

            // Calculate heading
            const dy = p2[0] - p1[0];
            const dx = Math.cos(p1[0] * Math.PI / 180) * (p2[1] - p1[1]);
            const angle = Math.atan2(dx, dy) * 180 / Math.PI;

            setPos({ lat: newLat, lon: newLon });
            setHeading(angle);
            setSpeed(7.5 + Math.random() * 1.5); // "Racing" speed
        }
    }, [pathProgress, isSimulating, path]);

    // Synchronize with Regatta Pro Socket
    useEffect(() => {
        if (socket && status === 'LIVE') {
            socket.emit('track-update', {
                boatId, // Explicitly send boatId to ensure backend knows which boat this is
                pos,
                imu: { heading, roll: 0, pitch: 0 },
                timestamp: Date.now(),
                dtl,
                velocity: { speed: parseFloat(speed.toFixed(1)), dir: heading }
            })
        }
    }, [pos, speed, dtl, socket, status, boatId, heading])

    const handleMapClick = (e: any) => {
        if (!isDrawing) return;
        setPath(prev => [...prev, [e.latlng.lat, e.latlng.lng]]);
    };

    return (
        <div className="min-h-screen bg-[#050507] text-white flex font-['Outfit'] select-none overflow-hidden">
            {/* Sidebar: Augmented Tracker Controls */}
            <aside className="w-80 border-r border-white/5 bg-black/40 backdrop-blur-xl flex flex-col p-6 z-20">
                <div className="flex items-center gap-3 mb-10">
                    <div className="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-500/20">
                        <Zap className="text-white fill-current" size={20} />
                    </div>
                    <h2 className="text-lg font-black italic tracking-tighter uppercase leading-none">Augmented <span className="text-blue-500">Tracker</span></h2>
                </div>

                <div className="flex-1 space-y-8 overflow-y-auto pr-2 custom-scrollbar">
                    <div className="space-y-4">
                        <div className="text-[10px] font-black text-gray-500 uppercase tracking-[0.2em]">Manual Path Architect</div>
                        <button
                            onClick={() => {
                                setIsDrawing(!isDrawing);
                                if (!isDrawing) setIsSimulating(false);
                            }}
                            className={`w-full py-4 rounded-2xl flex items-center justify-center gap-3 border transition-all ${isDrawing ? 'bg-blue-600 border-blue-400 text-white shadow-lg' : 'bg-white/5 border-white/10 text-gray-400 hover:bg-white/10'}`}
                        >
                            <MousePointer2 size={16} />
                            <span className="text-[11px] font-black uppercase tracking-widest">{isDrawing ? 'Finish Drawing' : 'Plot Waypoints'}</span>
                        </button>
                        <button
                            onClick={() => { setPath([]); setPathProgress(0); setIsSimulating(false); }}
                            className="w-full py-3 rounded-2xl flex items-center justify-center gap-3 bg-white/5 border border-white/10 text-gray-400 hover:bg-red-500/10 hover:border-red-500/30 hover:text-red-500 transition-all"
                        >
                            <Trash2 size={14} />
                            <span className="text-[10px] font-black uppercase tracking-widest">Clear Path</span>
                        </button>
                    </div>

                    <div className="space-y-4">
                        <div className="text-[10px] font-black text-gray-500 uppercase tracking-[0.2em]">Simulation Engine</div>
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
                            <span className="text-xs font-black uppercase tracking-widest">{isSimulating ? 'Kill Simulation' : 'Launch Path-Follow'}</span>
                        </button>

                        <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                            <div className="text-[9px] font-black text-gray-600 uppercase tracking-widest mb-3">Path Statistics</div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <div className="text-[8px] font-bold text-gray-500 uppercase">Path Length</div>
                                    <div className="text-lg font-black italic text-blue-500">
                                        {path.length > 1 ? (Math.sqrt(path.reduce((acc, p, i) => i === 0 ? 0 : acc + Math.pow(p[0] - path[i - 1][0], 2) + Math.pow(p[1] - path[i - 1][1], 2), 0)) * 60).toFixed(2) : '0.00'} <span className="text-[10px] lowercase">nm</span>
                                    </div>
                                </div>
                                <div>
                                    <div className="text-[8px] font-bold text-gray-500 uppercase">Est. Loop</div>
                                    <div className="text-lg font-black italic text-green-500">
                                        {path.length > 1 ? Math.floor(60 / (speed || 5)) : 0} <span className="text-[10px] lowercase">min</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="mt-8 pt-8 border-t border-white/5 space-y-4">
                    <button
                        onClick={() => window.location.href = '/'}
                        className="w-full py-3 rounded-xl flex items-center justify-center gap-3 bg-white/5 border border-white/10 text-gray-500 hover:text-white transition-all text-[10px] font-black uppercase tracking-widest"
                    >
                        <RotateCcw size={14} />
                        Back to Regatta Pro
                    </button>

                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-green-500/20 border border-green-500/30 flex items-center justify-center">
                            <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
                        </div>
                        <div>
                            <div className="text-[10px] font-black text-white leading-none">ID: {boatId}</div>
                            <div className="text-[8px] font-bold text-gray-500 uppercase tracking-widest mt-1">Uplink Stable</div>
                        </div>
                    </div>
                </div>
            </aside>

            {/* Main View: Map + Telemetry Overlay */}
            <div className="flex-1 relative bg-black">
                {/* Map Layer */}
                <div className="absolute inset-0 z-0">
                    <MapContainer
                        center={raceState?.defaultLocation ? [raceState.defaultLocation.lat, raceState.defaultLocation.lon] : [59.3293, 18.0686]}
                        zoom={raceState?.defaultLocation?.zoom || 15}
                        zoomControl={false}
                        className="w-full h-full"
                    >
                        <TileLayer url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" />
                        <MapEvents onMapClick={handleMapClick} />
                        <MapController raceState={raceState} />

                        {/* Course Context */}
                        {raceState?.course?.marks?.map((m: any) => (
                            <Marker
                                key={m.id}
                                position={[m.pos.lat, m.pos.lon]}
                                icon={L.divIcon({
                                    className: 'course-mark',
                                    html: `<div style="width: 12px; height: 12px; border-radius: 50%; border: 2px solid white; background: ${m.color || '#3b82f6'}; box-shadow: 0 0 10px rgba(0,0,0,0.5);"></div>`,
                                    iconSize: [12, 12],
                                    iconAnchor: [6, 6]
                                })}
                            />
                        ))}

                        {raceState?.course?.courseBoundary && (
                            <Polyline positions={raceState.course.courseBoundary.map((p: any) => [p.lat, p.lon])} color="#666" weight={1} dashArray="5,5" opacity={0.5} />
                        )}

                        <Polyline positions={path} color="#3B82F6" weight={3} dashArray="10, 10" opacity={0.6} />

                        {path.map((p, i) => (
                            <Marker
                                key={i}
                                position={p}
                                icon={L.divIcon({
                                    className: 'path-node',
                                    html: `<div class="w-2 h-2 bg-blue-500 rounded-full border border-white shadow-lg"></div>`,
                                    iconSize: [8, 8],
                                    iconAnchor: [4, 4]
                                })}
                            />
                        ))}

                        <Marker
                            position={[pos.lat, pos.lon]}
                            icon={TRACKER_BOAT_ICON(heading)}
                        />
                    </MapContainer>

                    {/* Vignette Overlay (Visual Parity) */}
                    <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(circle_at_center,transparent_20%,rgba(15,23,42,0.6)_100%)]" />
                </div>

                {/* HUD Overlay */}
                <div className="absolute inset-0 pointer-events-none p-10 flex flex-col z-10">
                    {/* Top Stats */}
                    <div className="flex justify-between items-start">
                        <div className="glass px-6 py-4 rounded-2xl border border-white/5 flex gap-8">
                            <div>
                                <div className="text-[10px] text-gray-500 font-black uppercase tracking-widest mb-0.5">SOG</div>
                                <div className="text-2xl font-black italic tracking-tighter tabular-nums">{speed.toFixed(1)}<span className="text-[10px] not-italic ml-0.5 opacity-50">kn</span></div>
                            </div>
                            <div className="w-px h-8 bg-white/5 self-center" />
                            <div>
                                <div className="text-[10px] text-gray-500 font-black uppercase tracking-widest mb-0.5">COG</div>
                                <div className="text-2xl font-black italic tracking-tighter tabular-nums">{Math.round(heading)}°</div>
                            </div>
                        </div>

                        <div className="glass px-6 py-4 rounded-2xl border border-white/5">
                            <div className="text-[10px] text-gray-500 font-black uppercase tracking-widest mb-0.5">DTL</div>
                            <div className="text-2xl font-black italic tracking-tighter tabular-nums text-blue-500">{dtl.toFixed(1)}<span className="text-[10px] not-italic ml-0.5 opacity-50">M</span></div>
                        </div>
                    </div>

                    <div className="flex-1" />

                    {/* Bottom Alerts */}
                    <AnimatePresence>
                        {raceState && (
                            <motion.div
                                initial={{ y: 50, opacity: 0 }}
                                animate={{ y: 0, opacity: 1 }}
                                className="bg-blue-600 rounded-[30px] p-6 flex items-center gap-6 shadow-2xl shadow-blue-600/30 ring-1 ring-white/20 self-center w-full max-w-lg mb-4 pointer-events-auto"
                            >
                                <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center">
                                    <Clock className="text-white" size={24} />
                                </div>
                                <div className="flex-1">
                                    <div className="flex justify-between items-end mb-1">
                                        <div className="text-[11px] text-blue-100 font-bold uppercase tracking-[0.2em] opacity-80">Sequence Running</div>
                                        <div className="text-2xl font-black tabular-nums italic tracking-tighter text-white">
                                            {Math.floor(raceState.time / 60)}:{(raceState.time % 60).toString().padStart(2, '0')}
                                        </div>
                                    </div>
                                    <div className="h-2 bg-black/20 rounded-full overflow-hidden">
                                        <motion.div
                                            initial={{ width: 0 }}
                                            animate={{ width: `${(raceState.time / 300) * 100}%` }}
                                            className="h-full bg-white rounded-full"
                                        />
                                    </div>
                                    <div className="mt-2 text-[10px] font-black uppercase tracking-widest flex items-center gap-2">
                                        <ChevronRight size={14} className="opacity-50" /> {raceState.event}
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>

                    {isDrawing && (
                        <div className="bg-amber-500/20 border border-amber-500/50 backdrop-blur-md px-6 py-3 rounded-xl self-center animate-pulse">
                            <span className="text-[10px] font-black uppercase text-amber-500 tracking-[0.3em]">Drawing Mode Active — Click map to architect path</span>
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}
