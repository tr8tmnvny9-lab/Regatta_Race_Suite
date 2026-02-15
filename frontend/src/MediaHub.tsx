import { useState, useEffect } from 'react'
import { io, Socket } from 'socket.io-client'
import { Play, Share2, Globe, Clock, Navigation, Wind, TrendingUp, BarChart3 } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapContainer, TileLayer, CircleMarker } from 'react-leaflet'

export default function MediaHub() {
    const [_socket, setSocket] = useState<Socket | null>(null)
    const [_boats, setBoats] = useState<Record<string, any>>({})
    const [delayedBoats, setDelayedBoats] = useState<Record<string, any>>({})
    const [_raceState, setRaceState] = useState<any>(null)

    useEffect(() => {
        const s = io('http://localhost:3001')
        setSocket(s)

        s.on('connect', () => {
            s.emit('register', { type: 'media' })
        })

        s.on('init-state', (state) => setRaceState(state))

        s.on('media-boat-update', (data: any) => {
            setBoats(prev => ({ ...prev, [data.boatId]: data }))
            // 2s delay simulation
            setTimeout(() => {
                setDelayedBoats(prev => ({ ...prev, [data.boatId]: data }))
            }, 2000)
        })

        return () => { s.close() }
    }, [])

    const sortedBoats = useMemo(() => {
        return Object.values(delayedBoats).sort((a: any, b: any) => a.dtl - b.dtl)
    }, [delayedBoats])

    return (
        <div className="min-h-screen bg-[#020204] text-white flex flex-col font-['Outfit'] overflow-hidden selection:bg-blue-600/30">
            {/* Cinematic Broadcast Header */}
            <header className="h-24 px-10 flex items-center justify-between border-b border-white/5 bg-black/40 backdrop-blur-3xl z-[1000]">
                <div className="flex items-center gap-8">
                    <div className="w-16 h-16 bg-white rounded-[24px] flex items-center justify-center p-0.5 shadow-2xl shadow-blue-500/20 glow-active">
                        <div className="w-full h-full bg-blue-600 rounded-[20px] flex items-center justify-center">
                            <Play className="text-white fill-current translate-x-0.5" size={28} />
                        </div>
                    </div>
                    <div>
                        <div className="flex items-center gap-2 mb-0.5">
                            <h1 className="text-3xl font-black italic tracking-tighter uppercase leading-none">Regatta <span className="text-blue-500">Live</span></h1>
                            <div className="px-2 py-0.5 rounded-lg bg-red-500/10 border border-red-500/20 text-[9px] font-black text-red-500 uppercase tracking-widest animate-pulse">4K Stream</div>
                        </div>
                        <div className="flex items-center gap-3 text-[10px] font-bold text-gray-500 uppercase tracking-[0.2em]">
                            <Globe size={12} className="text-blue-500" /> Stockholm Archipelago Championships 2026
                        </div>
                    </div>
                </div>

                <div className="flex items-center gap-10">
                    <div className="flex flex-col items-end">
                        <div className="flex items-center gap-3 text-white mb-1">
                            <Clock size={14} className="text-blue-500" />
                            <span className="text-xl font-black tabular-nums italic tracking-tighter leading-none">14:24:55</span>
                        </div>
                        <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest flex items-center gap-2">
                            Delayed Feed <span className="text-blue-500">+2.0s</span>
                        </div>
                    </div>

                    <div className="h-12 w-px bg-white/5" />

                    <button className="flex items-center gap-3 bg-white hover:bg-gray-100 text-black px-8 py-3.5 rounded-2xl font-black text-xs uppercase tracking-widest transition-all shadow-2xl shadow-white/10 group">
                        <Share2 size={16} className="group-hover:scale-110 transition-transform" /> Share Action
                    </button>
                </div>
            </header>

            <main className="flex-1 relative flex">
                {/* Cinematic Map Layer */}
                <div className="flex-1 relative">
                    <MapContainer
                        center={[59.3293, 18.0686]}
                        zoom={14}
                        zoomControl={false}
                        className="w-full h-full grayscale opacity-40 brightness-75 contrast-125"
                    >
                        <TileLayer url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png" />

                        {Object.entries(delayedBoats).map(([id, boat]: any) => (
                            <CircleMarker
                                key={id}
                                center={[boat.pos.lat, boat.pos.lon]}
                                radius={10}
                                pathOptions={{ color: '#3b82f6', fillColor: '#3b82f6', fillOpacity: 0.8, weight: 6 }}
                            />
                        ))}
                    </MapContainer>

                    {/* Broadcast HUD Overlay */}
                    <div className="absolute inset-0 pointer-events-none z-[999] p-10 flex flex-col justify-between">
                        {/* Dynamic Leaderboard Widget */}
                        <div className="flex justify-between items-start">
                            <motion.div
                                initial={{ x: -20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                className="bg-black/60 backdrop-blur-3xl p-10 rounded-[48px] border border-white/5 shadow-2xl w-full max-w-xl overflow-hidden"
                            >
                                <div className="flex items-center justify-between mb-8">
                                    <div className="flex items-center gap-4">
                                        <div className="w-2 h-10 bg-blue-600 rounded-full" />
                                        <h2 className="text-4xl font-black uppercase tracking-tighter italic leading-none">Fleet <span className="text-blue-500">Rankings</span></h2>
                                    </div>
                                    <div className="flex items-center gap-2 text-xs font-bold text-gray-500 bg-white/5 px-3 py-1 rounded-full">
                                        <TrendingUp size={14} className="text-blue-500" /> LIVE STATS
                                    </div>
                                </div>

                                <div className="space-y-6">
                                    <AnimatePresence mode="popLayout">
                                        {sortedBoats.slice(0, 5).map((boat: any, idx: number) => (
                                            <motion.div
                                                key={boat.boatId}
                                                layout
                                                initial={{ opacity: 0, x: -20 }}
                                                animate={{ opacity: 1, x: 0 }}
                                                className="flex items-center justify-between group"
                                            >
                                                <div className="flex items-center gap-6">
                                                    <span className="text-3xl font-black italic text-gray-800 group-hover:text-blue-500 transition-colors w-10">0{idx + 1}</span>
                                                    <div className="w-14 h-14 bg-white/5 rounded-2xl border border-white/10 flex items-center justify-center font-black text-xl italic group-hover:scale-105 transition-transform">
                                                        {boat.boatId.substring(0, 2)}
                                                    </div>
                                                    <div className="flex flex-col">
                                                        <span className="text-sm font-black tracking-tight uppercase group-hover:text-blue-500 transition-colors">{boat.boatId.substring(0, 8)}</span>
                                                        <span className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">DTL: {boat.dtl.toFixed(1)}m</span>
                                                    </div>
                                                </div>
                                                <div className="text-right">
                                                    <div className="text-2xl font-black italic tracking-tighter">{boat.velocity?.speed} <span className="text-[10px] font-normal not-italic text-gray-500 uppercase ml-1">knots</span></div>
                                                    <div className={`text-[9px] font-black uppercase tracking-widest ${boat.dtl < 10 ? 'text-red-500' : 'text-blue-500'}`}>
                                                        {boat.dtl < 10 ? 'OCS RISK' : 'CLEAR'}
                                                    </div>
                                                </div>
                                            </motion.div>
                                        ))}
                                    </AnimatePresence>
                                </div>
                            </motion.div>

                            {/* Right HUD: Environment Summary */}
                            <motion.div
                                initial={{ x: 20, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                className="flex flex-col gap-6 w-96"
                            >
                                <BroadcastPanel title="Wind Condition" icon={Wind}>
                                    <div className="flex items-center justify-between mt-2">
                                        <div>
                                            <div className="text-5xl font-black italic tracking-tighter">14.5<span className="text-sm font-normal text-gray-500 not-italic ml-1 opacity-50 uppercase">kn</span></div>
                                            <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mt-1">NNE • Dir: 245°</div>
                                        </div>
                                        <motion.div
                                            animate={{ rotate: 245 }}
                                            className="w-20 h-20 bg-blue-600 rounded-[32px] flex items-center justify-center shadow-2xl shadow-blue-600/30"
                                        >
                                            <Navigation size={48} className="text-white fill-current" />
                                        </motion.div>
                                    </div>
                                </BroadcastPanel>

                                <BroadcastPanel title="Course Data" icon={BarChart3}>
                                    <div className="space-y-4 py-2">
                                        <div>
                                            <div className="flex justify-between items-end mb-2">
                                                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">Race Progress</span>
                                                <span className="text-sm font-black italic">65<span className="text-[10px] font-normal not-italic ml-0.5">%</span></span>
                                            </div>
                                            <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
                                                <motion.div animate={{ width: '65%' }} className="h-full bg-blue-600 rounded-full" />
                                            </div>
                                        </div>
                                        <div className="grid grid-cols-2 gap-4">
                                            <div className="p-4 bg-white/5 rounded-2xl border border-white/5 text-center">
                                                <div className="text-2xl font-black italic">12.5</div>
                                                <div className="text-[9px] font-bold text-gray-500 uppercase tracking-widest mt-1">Avg Speed</div>
                                            </div>
                                            <div className="p-4 bg-white/5 rounded-2xl border border-white/5 text-center">
                                                <div className="text-2xl font-black italic">02</div>
                                                <div className="text-[9px] font-bold text-red-900 uppercase tracking-widest mt-1">Penalties</div>
                                            </div>
                                        </div>
                                    </div>
                                </BroadcastPanel>
                            </motion.div>
                        </div>

                        {/* Bottom Ticker/Status */}
                        <motion.div
                            initial={{ y: 20, opacity: 0 }}
                            animate={{ y: 0, opacity: 1 }}
                            className="bg-blue-600/90 backdrop-blur-3xl px-12 py-6 rounded-full border border-white/10 shadow-2xl flex items-center justify-between"
                        >
                            <div className="flex items-center gap-6">
                                <div className="text-[11px] font-black text-blue-100 uppercase tracking-[0.4em] opacity-80 border-r border-white/20 pr-6">Broadcast Channel 01</div>
                                <div className="text-lg font-black italic tracking-tighter text-white uppercase flex items-center gap-3">
                                    <div className="w-2 h-2 rounded-full bg-white glow-active" />
                                    Fleet approaching rounding mark #1 • Port tackle highly favored
                                </div>
                            </div>
                            <div className="text-[10px] font-black text-white hover:text-blue-100 uppercase tracking-widest cursor-pointer flex items-center gap-2">
                                More Angles <ChevronRight size={14} />
                            </div>
                        </motion.div>
                    </div>
                </div>
            </main>
        </div>
    )
}

function BroadcastPanel({ children, title, icon: Icon }: any) {
    return (
        <div className="bg-black/60 backdrop-blur-3xl p-8 rounded-[40px] border border-white/5 shadow-2xl overflow-hidden pointer-events-auto">
            <div className="flex items-center gap-3 mb-6">
                <Icon size={14} className="text-blue-500" />
                <h3 className="text-[10px] font-black text-gray-500 uppercase tracking-[0.3em]">{title}</h3>
            </div>
            {children}
        </div>
    )
}

import { useMemo } from 'react'
import { ChevronRight } from 'lucide-react'
