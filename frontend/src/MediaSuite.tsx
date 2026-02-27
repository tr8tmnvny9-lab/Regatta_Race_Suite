import React, { useState, useEffect } from 'react'
import { Globe, Monitor, LayoutGrid, SplitSquareHorizontal, Map as MapIcon, Aperture } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { LiveKitRoom } from '@livekit/components-react'
import VideoPlayer from './components/media/VideoPlayer'

type LayoutMode = 'QUAD' | 'SPLIT' | 'MAP_SPLIT' | 'SINGLE';

export default function MediaSuite({ socket, raceState, onHome }: { socket: any, raceState: any, onHome?: () => void }) {
    const [layout, setLayout] = useState<LayoutMode>('QUAD')
    const [autoDirector, setAutoDirector] = useState(true)
    const [liveKitToken, setLiveKitToken] = useState<string | null>(null)

    // Default server URL for local network testing (LiveKit SFU)
    const serverUrl = "ws://localhost:7880";

    useEffect(() => {
        if (!socket) return;
        socket.emit('register', { type: 'media' })

        // Mock token logic. In Phase B/C we will pull real secure tokens from Rust server
        setLiveKitToken('mock-auth-token')
    }, [socket])

    return (
        <div className="min-h-screen bg-[#020204] text-white flex flex-col font-['Outfit'] overflow-hidden selection:bg-blue-600/30">
            {/* Cinematic Broadcast Header */}
            <header className="h-24 px-10 flex items-center justify-between border-b border-white/5 bg-black/40 backdrop-blur-3xl z-[1000]">
                <div className="flex items-center gap-8">
                    <button
                        onClick={onHome}
                        className="w-16 h-16 bg-white rounded-[24px] flex items-center justify-center p-0.5 shadow-2xl shadow-blue-500/20 hover:scale-105 transition-transform"
                    >
                        <div className="w-full h-full bg-blue-600 rounded-[20px] flex items-center justify-center">
                            <Monitor className="text-white" size={28} />
                        </div>
                    </button>
                    <div>
                        <div className="flex items-center gap-2 mb-0.5">
                            <h1 className="text-3xl font-black italic tracking-tighter uppercase leading-none">Regatta <span className="text-blue-500">Suite</span></h1>
                            <div className="px-2 py-0.5 rounded-lg bg-red-500/10 border border-red-500/20 text-[9px] font-black text-red-500 uppercase tracking-widest animate-pulse">LIVE BROADCAST</div>
                        </div>
                        <div className="flex items-center gap-3 text-[10px] font-bold text-gray-500 uppercase tracking-[0.2em]">
                            <Globe size={12} className="text-blue-500" /> WebRTC SFU CONNECTED
                        </div>
                    </div>
                </div>

                {/* Director Toolbar */}
                <div className="flex items-center gap-6 bg-white/5 p-2 rounded-2xl border border-white/10">
                    <button onClick={() => setLayout('QUAD')} className={`p-3 rounded-xl transition-all ${layout === 'QUAD' ? 'bg-blue-600 text-white' : 'text-gray-400 hover:bg-white/10'}`}>
                        <LayoutGrid size={20} />
                    </button>
                    <button onClick={() => setLayout('SPLIT')} className={`p-3 rounded-xl transition-all ${layout === 'SPLIT' ? 'bg-blue-600 text-white' : 'text-gray-400 hover:bg-white/10'}`}>
                        <SplitSquareHorizontal size={20} />
                    </button>
                    <button onClick={() => setLayout('MAP_SPLIT')} className={`p-3 rounded-xl transition-all ${layout === 'MAP_SPLIT' ? 'bg-blue-600 text-white' : 'text-gray-400 hover:bg-white/10'}`}>
                        <MapIcon size={20} />
                    </button>
                    <div className="w-px h-8 bg-white/10" />
                    <button
                        onClick={() => setAutoDirector(!autoDirector)}
                        className={`flex items-center gap-2 px-4 py-2 rounded-xl transition-all text-xs font-black uppercase tracking-widest border ${autoDirector ? 'bg-green-500/20 text-green-400 border-green-500/50' : 'bg-white/5 text-gray-400 border-white/10'}`}
                    >
                        <Aperture size={16} className={autoDirector ? 'animate-spin-slow' : ''} />
                        Auto-Dir {autoDirector ? 'ON' : 'OFF'}
                    </button>
                </div>
            </header>

            <main className="flex-1 relative flex p-6 gap-6">

                {/* LiveKit Room Wrapper */}
                <LiveKitRoom
                    video={false}
                    audio={false}
                    token={liveKitToken ?? ''}
                    serverUrl={serverUrl}
                    connect={false} // Currently false so it doesn't try to connect to localhost without server
                    className="w-full h-full flex gap-6"
                >
                    <MediaGrid layout={layout} raceState={raceState} autoDirector={autoDirector} />
                </LiveKitRoom>

                {/* Sponsor Bug Overlay */}
                <div className="absolute top-10 right-10 flex gap-4 z-[1001] pointer-events-none">
                    <div className="bg-gradient-to-tr from-blue-900 to-black backdrop-blur-xl p-4 rounded-3xl border border-blue-500/30 shadow-[0_0_30px_rgba(59,130,246,0.3)] flex items-center justify-center w-56 h-20 transition-all">
                        <div className="text-blue-300 text-[10px] font-black uppercase tracking-widest text-center leading-tight">
                            Powered By<br />
                            <span className="text-white text-2xl mt-1 tracking-tighter italic block drop-shadow-lg font-sans font-black">LiveKit</span>
                        </div>
                    </div>
                </div>

            </main>
        </div>
    )
}

// Subcomponent to organize tracks based on layout
function MediaGrid({ layout, raceState, autoDirector }: { layout: LayoutMode, raceState: any, autoDirector: boolean }) {
    // In production we would pull active video tracks using `useTracks`
    // const tracks = useTracks([Track.Source.Camera], { onlySubscribed: true });

    // For Phase A, we render mocked placeholders to prove the layout logic
    const mockFeeds = [
        { id: 'boat-1', name: 'SWE-42', debugColor: '59,130,246' },
        { id: 'boat-2', name: 'FIN-18', debugColor: '239,68,68' },
        { id: 'boat-3', name: 'DEN-07', debugColor: '34,197,94' },
        { id: 'boat-4', name: 'NOR-99', debugColor: '234,179,8' },
    ]

    return (
        <AnimatePresence mode="popLayout">
            {layout === 'QUAD' && (
                <motion.div
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="w-full h-full grid grid-cols-2 grid-rows-2 gap-4"
                >
                    {mockFeeds.map((feed, i) => (
                        <div key={feed.id} className="relative rounded-2xl overflow-hidden bg-black ring-1 ring-white/10 shadow-2xl">
                            <VideoPlayer fallbackName={feed.name} isLive={autoDirector && i === 0} debugColor={feed.debugColor} />
                        </div>
                    ))}
                </motion.div>
            )}

            {layout === 'SPLIT' && (
                <motion.div
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="w-full h-full grid grid-cols-2 gap-6"
                >
                    <div className="h-full rounded-[32px] overflow-hidden bg-black ring-1 ring-white/10 shadow-2xl">
                        <VideoPlayer fallbackName={mockFeeds[0].name} isLive={autoDirector} debugColor={mockFeeds[0].debugColor} />
                    </div>
                    <div className="h-full rounded-[32px] overflow-hidden bg-black ring-1 ring-white/10 shadow-2xl">
                        <VideoPlayer fallbackName={mockFeeds[1].name} isLive={false} debugColor={mockFeeds[1].debugColor} />
                    </div>
                </motion.div>
            )}

            {layout === 'MAP_SPLIT' && (
                <motion.div
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="w-full h-full flex gap-6"
                >
                    <div className="flex-1 h-full rounded-[32px] overflow-hidden bg-black ring-1 ring-white/10 shadow-2xl">
                        <VideoPlayer fallbackName={mockFeeds[0].name} isLive={autoDirector} debugColor={mockFeeds[0].debugColor} />
                    </div>
                    <div className="w-[600px] h-full rounded-[32px] overflow-hidden bg-black ring-1 ring-white/10 shadow-2xl relative">
                        {/* Mock tactical map placeholder to prove layout works. In production we'd mount TacticalMap.tsx here */}
                        <div className="absolute inset-0 bg-[#04060A] flex flex-col items-center justify-center text-white/20">
                            <MapIcon size={48} className="mb-4" />
                            <span className="font-black uppercase tracking-widest text-sm">Tactical Telemetry Map</span>
                        </div>
                        <div className="absolute top-4 left-4 px-2.5 py-1 bg-black/60 backdrop-blur-md border border-white/10 rounded text-[10px] font-bold uppercase text-white tracking-widest shadow-lg">
                            Regatta Tracking View
                        </div>
                    </div>
                </motion.div>
            )}
        </AnimatePresence>
    )
}
