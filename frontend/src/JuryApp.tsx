import { useState, useEffect } from 'react'
import { io, Socket } from 'socket.io-client'
import { Gavel, Crosshair, Users, ChevronRight, ShieldAlert } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import MiniTimeline from './components/MiniTimeline'

export default function JuryApp() {
    const [socket, setSocket] = useState<Socket | null>(null)
    const [boats, setBoats] = useState<Record<string, any>>({})
    const [nearbyBoats, setNearbyBoats] = useState<string[]>([])
    const [selectedBoat, setSelectedBoat] = useState<string | null>(null)
    const [raceState, setRaceState] = useState<any>(null)

    useEffect(() => {
        const s = io('http://localhost:3001')
        setSocket(s)

        s.on('connect', () => {
            s.emit('register', { type: 'jury' })
        })

        s.on('init-state', (state) => {
            setBoats(state.boats)
            setRaceState(state)
        })

        s.on('boat-update', (data) => {
            setBoats(prev => ({ ...prev, [data.boatId]: { ...data, lastUpdate: Date.now() } }))
            // Proximity simulation: if DTL is low or updated recently
            setNearbyBoats(prev => Array.from(new Set([...prev, data.boatId])).slice(-4))
        })

        s.on('sequence-update', (data) => {
            setRaceState((prev: any) => ({ ...prev, sequence: data }))
        })

        return () => { s.close() }
    }, [])

    const issuePenalty = (type: string) => {
        if (selectedBoat && socket) {
            socket.emit('issue-penalty', {
                boatId: selectedBoat,
                type,
                timestamp: Date.now()
            })
            setSelectedBoat(null)
        }
    }

    return (
        <div className="min-h-screen bg-[#050507] text-white p-8 flex flex-col font-['Outfit'] select-none">
            {/* Premium Header */}
            <header className="h-24 px-8 glass rounded-3xl flex items-center justify-between mb-8 border border-white/5 shadow-2xl">
                <div className="flex items-center gap-6">
                    <div className="w-14 h-14 bg-orange-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-orange-600/30 glow-active">
                        <Gavel className="text-white fill-current" size={28} />
                    </div>
                    <div>
                        <h1 className="text-2xl font-black italic tracking-tighter uppercase leading-none text-orange-500">Jury <span className="text-white">Console</span></h1>
                        <div className="flex items-center gap-2 mt-1.5 font-bold text-[9px] text-gray-500 uppercase tracking-widest">
                            <span className="w-1.5 h-1.5 rounded-full bg-green-500" /> System: On Station • Authority: International
                        </div>
                    </div>
                </div>

                <div className="flex items-center gap-6">
                    <div className="text-right">
                        <div className="text-[10px] text-gray-500 font-bold uppercase tracking-widest mb-0.5 opacity-60">Fleet Tracking</div>
                        <div className="text-xl font-black italic tabular-nums">{Object.keys(boats).length} Active</div>
                    </div>
                    <div className="w-px h-10 bg-white/5" />
                    <div className="w-14 h-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center hover:bg-white/10 transition-all cursor-pointer">
                        <Crosshair className="text-white opacity-40" size={24} />
                    </div>
                </div>
            </header>

            <main className="flex-1 flex flex-col gap-10">
                {/* Proximity Suggestion Engine */}
                <section>
                    <div className="flex items-center justify-between mb-6 px-1">
                        <h2 className="text-[11px] font-black text-gray-500 uppercase tracking-[0.3em] flex items-center gap-3">
                            <Users size={14} className="text-orange-500" /> Proximity Suggestion Queue
                        </h2>
                        <span className="text-[10px] font-bold text-gray-600 bg-white/5 px-2 py-0.5 rounded-lg border border-white/5">Auto-Detect ON</span>
                    </div>

                    <div className="grid grid-cols-2 gap-6">
                        <AnimatePresence mode="popLayout">
                            {nearbyBoats.map(id => (
                                <motion.button
                                    key={id}
                                    layout
                                    initial={{ opacity: 0, scale: 0.95 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.9 }}
                                    whileTap={{ scale: 0.97 }}
                                    onClick={() => setSelectedBoat(id)}
                                    className={`relative p-6 rounded-[32px] border transition-all flex items-center justify-between overflow-hidden ${selectedBoat === id ? 'bg-orange-500/10 border-orange-500 shadow-2xl shadow-orange-500/20' : 'bg-[#0a0a0c] border-white/5 hover:border-white/10'}`}
                                >
                                    {selectedBoat === id && (
                                        <motion.div
                                            layoutId="choice-bg"
                                            className="absolute inset-x-0 bottom-0 h-1 bg-orange-500 shadow-[0_-4px_12px_rgba(249,115,22,0.4)]"
                                        />
                                    )}
                                    <div className="flex items-center gap-5">
                                        <div className={`w-12 h-12 rounded-2xl flex items-center justify-center font-black italic text-xl ${selectedBoat === id ? 'bg-orange-600 text-white' : 'bg-white/5 text-gray-500'}`}>
                                            {id.substring(0, 2).toUpperCase()}
                                        </div>
                                        <div className="text-left">
                                            <div className="text-xl font-black italic tracking-tighter uppercase">{id.substring(0, 8)}</div>
                                            <div className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-0.5">Rel Dist: <span className="text-orange-500">14.2M</span></div>
                                        </div>
                                    </div>
                                    <ChevronRight className={selectedBoat === id ? 'text-orange-500' : 'text-gray-800'} size={24} />
                                </motion.button>
                            ))}
                            {nearbyBoats.length === 0 && (
                                <div className="col-span-2 py-10 border border-dashed border-white/10 rounded-[32px] flex flex-col items-center justify-center opacity-30">
                                    <ShieldAlert size={40} className="mb-4" />
                                    <span className="text-xs font-black uppercase tracking-[0.2em]">Searching for nearby targets...</span>
                                </div>
                            )}
                        </AnimatePresence>
                    </div>
                </section>

                {/* Action Matrix */}
                <div className="flex-1 flex flex-col justify-end gap-10">
                    <AnimatePresence>
                        {selectedBoat && (
                            <motion.section
                                initial={{ y: 200, opacity: 0 }}
                                animate={{ y: 0, opacity: 1 }}
                                exit={{ y: 200, opacity: 0 }}
                                className="bg-[#0a0a0e] rounded-[40px] p-8 border border-white/10 shadow-[0_0_100px_rgba(249,115,22,0.1)] relative overflow-hidden"
                            >
                                <div className="absolute top-0 right-0 p-8">
                                    <button onClick={() => setSelectedBoat(null)} className="text-[11px] font-black text-gray-600 hover:text-white transition-colors uppercase tracking-widest">Discard Action</button>
                                </div>

                                <div className="flex items-center gap-6 mb-10">
                                    <div className="w-1 h-12 bg-orange-600 rounded-full" />
                                    <div>
                                        <div className="text-[11px] text-gray-500 font-black uppercase tracking-[0.3em] mb-1">Applying Verdict To</div>
                                        <div className="text-4xl font-black italic tracking-tighter uppercase text-white">{selectedBoat}</div>
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-6">
                                    <PenaltyAction label="PORT / STARBOARD" type="P/S" onClick={() => issuePenalty('P-S')} />
                                    <PenaltyAction label="MARK ROOM VIOLATION" type="ROOM" onClick={() => issuePenalty('ROOM')} />
                                    <PenaltyAction label="OCS / EARLY START" type="OCS" onClick={() => issuePenalty('OCS')} />
                                    <PenaltyAction label="TOUCHED MARK" type="TOUCH" onClick={() => issuePenalty('TOUCH')} />
                                </div>
                            </motion.section>
                        )}
                    </AnimatePresence>

                    {/* Persistent Procedural HUD (Mini Timeline) */}
                    <div className="absolute top-8 left-1/2 -translate-x-1/2 z-50">
                        <MiniTimeline
                            raceStatus={raceState?.status || 'IDLE'}
                            currentSequence={raceState?.sequence?.currentSequence?.event || null}
                            sequenceTimeRemaining={raceState?.sequence?.sequenceTimeRemaining ?? null}
                            currentFlags={raceState?.sequence?.currentSequence?.flags || []}
                        />
                    </div>
                </div>
            </main>
        </div>
    )
}

const PenaltyAction = ({ label, type, onClick }: any) => (
    <button
        onClick={onClick}
        className="group h-24 relative rounded-3xl bg-white/[0.03] border border-white/5 hover:border-orange-500/50 hover:bg-orange-500/10 transition-all flex flex-col items-center justify-center gap-1 overflow-hidden"
    >
        <div className="absolute inset-0 bg-gradient-to-br from-orange-600/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
        <div className="text-[10px] font-black text-gray-500 group-hover:text-orange-500 transition-colors tracking-widest leading-none">{type}</div>
        <div className="text-xs font-black text-white group-hover:scale-105 transition-transform tracking-tight">{label}</div>
    </button>
)
