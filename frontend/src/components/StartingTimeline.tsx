import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Play, AlertTriangle, RotateCcw, ChevronDown } from 'lucide-react'
import type { Socket } from 'socket.io-client'

import { FlagIcon, flagLabel } from './FlagIcons'


// ═══════════════════════════════════════════════════════════════
//  TIMELINE STEP DEFINITION
// ═══════════════════════════════════════════════════════════════

interface TimelineStep {
    id: string
    time: string             // Display time like "-5:00"
    seconds: number          // When this step triggers (300, 240, 60, 0)
    label: string
    description: string
    flagsUp: string[]        // Flags raised at this moment
    flagsDown: string[]      // Flags lowered at this moment
}

const STANDARD_SEQUENCE: TimelineStep[] = [
    {
        id: 'idle',
        time: '-5:00',
        seconds: 300,
        label: 'IDLE',
        description: 'Waiting for warning signal',
        flagsUp: [],
        flagsDown: [],
    },
    {
        id: 'warning',
        time: '-5:00',
        seconds: 300,
        label: 'WARNING SIGNAL',
        description: 'Class flag is raised with one sound signal',
        flagsUp: ['CLASS'],
        flagsDown: [],
    },
    {
        id: 'preparatory',
        time: '-4:00',
        seconds: 240,
        label: 'PREPARATORY SIGNAL',
        description: 'Preparatory flag raised with one sound signal',
        flagsUp: ['PREP'],   // Will be replaced dynamically with actual prep flag
        flagsDown: [],
    },
    {
        id: 'one_minute',
        time: '-1:00',
        seconds: 60,
        label: 'ONE-MINUTE SIGNAL',
        description: 'Prep flag lowered with one long sound signal',
        flagsUp: [],
        flagsDown: ['PREP'], // Will be replaced dynamically
    },
    {
        id: 'start',
        time: '0:00',
        seconds: 0,
        label: 'STARTING SIGNAL',
        description: 'Class flag lowered with one sound signal',
        flagsUp: [],
        flagsDown: ['CLASS'],
    },
]

// ═══════════════════════════════════════════════════════════════
//  MAIN COMPONENT
// ═══════════════════════════════════════════════════════════════

interface StartingTimelineProps {
    socket: Socket | null
    raceStatus: string
    sequenceTimeRemaining: number | null
    currentFlags: string[]
    currentEvent: string | null
    prepFlag: string
    currentProcedure: any | null
    currentNodeId: string | null
}

function formatTime(seconds: number) {
    const m = Math.floor(Math.abs(seconds) / 60);
    const s = Math.floor(Math.abs(seconds) % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function StartingTimeline({
    socket,
    raceStatus,
    sequenceTimeRemaining,
    currentFlags,
    currentEvent,
    prepFlag,
    currentProcedure,
    currentNodeId,
}: StartingTimelineProps) {
    const [selectedPrepFlag, setSelectedPrepFlag] = useState<string>(prepFlag || 'P')
    const [showPrepSelector, setShowPrepSelector] = useState(false)
    const [showSpecialActions, setShowSpecialActions] = useState(false)



    const isActive = raceStatus === 'PRE_START'
    const isIdle = raceStatus === 'IDLE'
    const isSpecial = ['POSTPONED', 'RECALL', 'ABANDONED'].includes(raceStatus)
    const isRacing = raceStatus === 'RACING'

    // Build dynamic steps from procedure graph if available, else fallback to standard
    const getFlowSteps = (): TimelineStep[] => {
        if (!currentProcedure || !currentProcedure.nodes || currentProcedure.nodes.length === 0) {
            return STANDARD_SEQUENCE.map(step => ({
                ...step,
                flagsUp: step.flagsUp.map(f => f === 'PREP' ? selectedPrepFlag : f),
                flagsDown: step.flagsDown.map(f => f === 'PREP' ? selectedPrepFlag : f),
            }))
        }

        // Trace the primary path (simplified: follow first edge from each node starting at '1')
        const flowSteps: TimelineStep[] = []

        let currId: string | undefined = '1'
        const visited = new Set<string>()

        // Fallback to first node if '1' doesn't exist
        if (!currentProcedure.nodes.find((n: any) => n.id === '1')) {
            currId = currentProcedure.nodes[0]?.id
        }

        // First pass: find all primary nodes to calculate total duration
        const primaryNodes: any[] = []
        let tempId = currId
        while (tempId && !visited.has(tempId)) {
            const node = currentProcedure.nodes.find((n: any) => n.id === tempId)
            if (!node) break
            primaryNodes.push(node)
            visited.add(tempId)
            tempId = currentProcedure.edges.find((e: any) => e.source === tempId)?.target
        }

        const totalDuration = primaryNodes.reduce((acc, n) => acc + (n.data.duration || 0), 0)
        let timeRemaining = totalDuration

        primaryNodes.forEach(node => {
            flowSteps.push({
                id: node.id,
                time: `-${formatTime(timeRemaining)}`,
                seconds: timeRemaining,
                label: (node.data.label || 'UNTITLED').toUpperCase(),
                description: node.data.description || `Automatic transition in ${node.data.duration}s`,
                flagsUp: node.data.flags || [],
                flagsDown: [], // Node system usually defines what's UP at each state
            })
            timeRemaining -= (node.data.duration || 0)
        })

        return flowSteps
    }

    const steps = getFlowSteps()

    // Find special nodes (nodes not in the primary path)
    const getSpecialNodes = () => {
        if (!currentProcedure || !currentProcedure.nodes) return []
        const primaryIds = new Set(steps.map(s => s.id))
        return currentProcedure.nodes.filter((n: any) => !primaryIds.has(n.id))
    }

    const specialNodes = getSpecialNodes()

    // Determine which step is currently active
    const getActiveStepIndex = (): number => {
        if (!isActive || !currentNodeId) return -1
        return steps.findIndex(s => s.id === currentNodeId)
    }

    const activeStepIdx = getActiveStepIndex()

    // Calculate progress percentage through the sequence
    const totalSeqTime = steps.length > 0 ? steps[0].seconds : 300
    const progressPercent = isActive && sequenceTimeRemaining !== null
        ? Math.max(0, Math.min(100, ((totalSeqTime - sequenceTimeRemaining) / totalSeqTime) * 100))
        : isRacing ? 100 : 0

    const handleStartSequence = () => {
        socket?.emit('start-sequence', { minutes: 5, prepFlag: selectedPrepFlag })
    }

    const handlePrepFlagChange = (flag: string) => {
        setSelectedPrepFlag(flag)
        socket?.emit('set-prep-flag', flag)
        setShowPrepSelector(false)
    }

    return (
        <div className="flex flex-col h-full min-h-[400px]">
            <div className="text-[8px] font-black text-accent-cyan/40 uppercase tracking-[0.4em] mb-4 pointer-events-none">Sequence Intelligence Active</div>

            {/* ── Big Countdown Display ── */}
            <div className="text-center mb-6">
                <AnimatePresence mode="wait">
                    {isActive && sequenceTimeRemaining !== null && (
                        <motion.div
                            key="countdown"
                            initial={{ opacity: 0, scale: 0.7, filter: 'blur(20px)' }}
                            animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
                            exit={{ opacity: 0, scale: 1.2, filter: 'blur(10px)' }}
                            className="relative"
                        >
                            <div className="text-7xl font-black italic tracking-tighter tabular-nums text-white leading-none">
                                {formatTime(sequenceTimeRemaining)}
                            </div>
                            <div className="text-[10px] font-black uppercase tracking-[0.4em] text-accent-cyan mt-2">
                                {currentEvent || 'SEQUENCE ACTIVE'}
                            </div>
                        </motion.div>
                    )}
                    {isIdle && (
                        <motion.div
                            key="idle"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                        >
                            <div className="text-5xl font-black italic tracking-tighter text-gray-700 leading-none">
                                5:00
                            </div>
                            <div className="text-[10px] font-black uppercase tracking-[0.4em] text-gray-600 mt-2">
                                READY TO START
                            </div>
                        </motion.div>
                    )}
                    {isSpecial && (
                        <motion.div
                            key="special"
                            initial={{ opacity: 0, y: -10 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0 }}
                        >
                            <div className={`text-4xl font-black italic tracking-tighter leading-none ${raceStatus === 'POSTPONED' ? 'text-amber-400' :
                                raceStatus === 'RECALL' ? 'text-accent-cyan' :
                                    'text-accent-red'
                                }`}>
                                {raceStatus.replace('_', ' ')}
                            </div>
                        </motion.div>
                    )}
                    {isRacing && (
                        <motion.div
                            key="racing"
                            initial={{ opacity: 0, scale: 0.8 }}
                            animate={{ opacity: 1, scale: 1 }}
                        >
                            <div className="text-4xl font-black italic tracking-tighter text-accent-green leading-none">
                                RACING
                            </div>
                            <div className="text-[10px] font-black uppercase tracking-[0.4em] text-accent-green/60 mt-2">
                                SEQUENCE COMPLETE
                            </div>
                        </motion.div>
                    )}
                    {!(isActive || isIdle || isSpecial || isRacing) && (
                        <div className="text-2xl font-black uppercase text-gray-500">
                            {raceStatus || 'UNKNOWN STATUS'}
                        </div>
                    )}
                </AnimatePresence>
            </div>

            {/* ── Active Flags Display ── */}
            <div className="mb-6">
                <div className="text-[9px] font-black text-gray-500 uppercase tracking-[0.3em] mb-3">Active Flags</div>
                <div className="flex gap-3 min-h-[50px] items-center flex-wrap">
                    <AnimatePresence mode="popLayout">
                        {currentFlags.length > 0 ? currentFlags.map(flag => (
                            <motion.div
                                key={flag}
                                initial={{ opacity: 0, y: 20, scale: 0.5 }}
                                animate={{ opacity: 1, y: 0, scale: 1 }}
                                exit={{ opacity: 0, y: -20, scale: 0.5, transition: { duration: 0.2 } }}
                                layout
                                className="flex flex-col items-center gap-1.5"
                            >
                                <div className="p-2 bg-white/5 rounded-xl border border-white/10 hover:border-accent-blue/40 transition-all">
                                    <FlagIcon flag={flag} size={56} />
                                </div>
                                <span className="text-[8px] font-black text-gray-400 uppercase tracking-widest">
                                    {flagLabel[flag] || flag}
                                </span>
                            </motion.div>
                        )) : (
                            <motion.div
                                key="no-flags"
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 0.4 }}
                                className="text-[10px] font-bold text-gray-600 uppercase tracking-widest py-3"
                            >
                                No flags displayed
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </div>

            {/* ── Progress Bar ── */}
            <div className="mb-6">
                <div className="h-1.5 bg-white/5 rounded-full overflow-hidden relative">
                    <motion.div
                        className="h-full rounded-full"
                        style={{
                            background: isSpecial
                                ? 'linear-gradient(90deg, #f59e0b, #ef4444)'
                                : 'linear-gradient(90deg, #3b82f6, #06b6d4)'
                        }}
                        animate={{ width: `${progressPercent}%` }}
                        transition={{ duration: 0.5, ease: 'easeOut' }}
                    />
                    {/* Milestone markers */}
                    {[0, 20, 80, 100].map((pos, i) => (
                        <div
                            key={i}
                            className="absolute top-1/2 -translate-y-1/2 w-2 h-2 rounded-full border border-gray-700 bg-regatta-dark"
                            style={{ left: `${pos}%`, transform: `translate(-50%, -50%)` }}
                        />
                    ))}
                </div>
                <div className="flex justify-between mt-1.5 text-[8px] font-bold text-gray-600 uppercase tracking-widest px-2">
                    {steps.filter((_, i) => i % Math.max(1, Math.floor(steps.length / 4)) === 0 || i === steps.length - 1).map(s => (
                        <span key={s.id}>{s.time}</span>
                    ))}
                </div>
            </div>

            {/* ── Vertical Timeline ── */}
            <div className="flex-1 overflow-y-auto pr-1 custom-scrollbar">
                <div className="relative pl-6">
                    {/* Vertical line */}
                    <div className="absolute left-[7px] top-2 bottom-2 w-[2px] bg-white/5" />

                    {/* Animated progress on the line */}
                    {isActive && (
                        <motion.div
                            className="absolute left-[7px] top-2 w-[2px] bg-gradient-to-b from-accent-blue to-accent-cyan"
                            animate={{
                                height: `${Math.min(100, (activeStepIdx + 1) / steps.length * 100)}%`
                            }}
                            transition={{ duration: 0.5 }}
                        />
                    )}

                    {steps.map((step, idx) => {
                        const isPast = isActive && activeStepIdx > idx
                        const isCurrent = isActive && activeStepIdx === idx
                        const isCompleted = isRacing

                        return (
                            <div key={step.id} className="relative mb-6 group">
                                {/* Dot */}
                                <div className={`absolute left-[-17px] w-4 h-4 rounded-full border-2 z-10 transition-all duration-500
                                    ${isCurrent
                                        ? 'bg-accent-blue border-accent-blue shadow-[0_0_20px_rgba(59,130,246,0.8)] scale-125'
                                        : isPast || isCompleted
                                            ? 'bg-accent-cyan border-accent-cyan/50'
                                            : 'bg-regatta-dark border-gray-700'
                                    }`}
                                >
                                    {isCurrent && (
                                        <motion.div
                                            className="absolute inset-0 rounded-full bg-accent-blue"
                                            animate={{ scale: [1, 2, 1], opacity: [0.8, 0, 0.8] }}
                                            transition={{ duration: 2, repeat: Infinity }}
                                        />
                                    )}
                                </div>

                                {/* Content */}
                                <div className={`transition-all duration-300 ${isCurrent ? 'translate-x-1' : ''}`}>
                                    <div className="flex items-center gap-3 mb-1">
                                        <span className={`text-[10px] font-black uppercase tracking-[0.3em] transition-colors ${isCurrent ? 'text-accent-blue' :
                                            isPast || isCompleted ? 'text-accent-cyan/60' :
                                                'text-gray-600'
                                            }`}>
                                            {step.time}
                                        </span>
                                    </div>
                                    <div className={`text-sm font-black italic uppercase tracking-tight mb-1 transition-colors ${isCurrent ? 'text-white' :
                                        isPast || isCompleted ? 'text-gray-400' :
                                            'text-gray-700'
                                        }`}>
                                        {step.label}
                                    </div>
                                    <div className={`text-[10px] transition-colors mb-2 ${isCurrent ? 'text-gray-300' :
                                        isPast || isCompleted ? 'text-gray-500' :
                                            'text-gray-700'
                                        }`}>
                                        {step.description}
                                    </div>

                                    {/* Flag changes at this step */}
                                    <div className="flex gap-2 flex-wrap">
                                        {step.flagsUp.map(f => (
                                            <div key={`up-${f}`} className={`flex items-center gap-1.5 px-2 py-1 rounded-lg text-[8px] font-black uppercase tracking-widest border transition-all ${isCurrent || isPast || isCompleted
                                                ? 'bg-accent-green/10 border-accent-green/30 text-accent-green'
                                                : 'bg-white/5 border-white/5 text-gray-600'
                                                }`}>
                                                <span>▲</span>
                                                <FlagIcon flag={f} size={20} />
                                                <span>{flagLabel[f] || f}</span>
                                            </div>
                                        ))}
                                        {step.flagsDown.map(f => (
                                            <div key={`dn-${f}`} className={`flex items-center gap-1.5 px-2 py-1 rounded-lg text-[8px] font-black uppercase tracking-widest border transition-all ${isCurrent || isPast || isCompleted
                                                ? 'bg-accent-red/10 border-accent-red/30 text-accent-red'
                                                : 'bg-white/5 border-white/5 text-gray-600'
                                                }`}>
                                                <span>▼</span>
                                                <FlagIcon flag={f} size={20} />
                                                <span>{flagLabel[f] || f}</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        )
                    })}
                </div>
            </div>

            {/* ── Controls ── */}
            <div className="mt-4 pt-4 border-t border-white/10 space-y-3">

                {/* Prep Flag Selector */}
                {isIdle && (
                    <div className="relative">
                        <button
                            onClick={() => setShowPrepSelector(!showPrepSelector)}
                            className="w-full flex items-center justify-between p-3 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl transition-all"
                        >
                            <div className="flex items-center gap-3">
                                <FlagIcon flag={selectedPrepFlag} size={28} />
                                <div className="text-left">
                                    <div className="text-[9px] font-black text-gray-500 uppercase tracking-widest">Prep Flag</div>
                                    <div className="text-xs font-bold text-white">{flagLabel[selectedPrepFlag]}</div>
                                </div>
                            </div>
                            <ChevronDown size={14} className={`text-gray-500 transition-transform ${showPrepSelector ? 'rotate-180' : ''}`} />
                        </button>

                        <AnimatePresence>
                            {showPrepSelector && (
                                <motion.div
                                    initial={{ opacity: 0, y: -5, height: 0 }}
                                    animate={{ opacity: 1, y: 0, height: 'auto' }}
                                    exit={{ opacity: 0, y: -5, height: 0 }}
                                    className="mt-2 bg-regatta-panel border border-white/10 rounded-xl overflow-hidden"
                                >
                                    {['P', 'I', 'Z', 'U', 'BLACK'].map(flag => (
                                        <button
                                            key={flag}
                                            onClick={() => handlePrepFlagChange(flag)}
                                            className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-white/5 transition-all text-left ${selectedPrepFlag === flag ? 'bg-accent-blue/10 border-l-2 border-accent-blue' : 'border-l-2 border-transparent'
                                                }`}
                                        >
                                            <FlagIcon flag={flag} size={24} />
                                            <div>
                                                <div className="text-xs font-bold text-white">{flagLabel[flag]}</div>
                                                <div className="text-[8px] text-gray-500 uppercase tracking-widest">
                                                    {flag === 'P' && 'Standard preparatory'}
                                                    {flag === 'I' && 'Round-the-ends rule'}
                                                    {flag === 'Z' && '20% scoring penalty'}
                                                    {flag === 'U' && 'UFD — no comeback'}
                                                    {flag === 'BLACK' && 'DSQ — disqualification'}
                                                </div>
                                            </div>
                                        </button>
                                    ))}
                                </motion.div>
                            )}
                        </AnimatePresence>
                    </div>
                )}

                {/* Start Button */}
                {isIdle && (
                    <button
                        onClick={handleStartSequence}
                        className="w-full py-4 bg-accent-blue hover:bg-blue-600 text-white rounded-xl font-black uppercase tracking-[0.2em] text-xs flex items-center justify-center gap-3 shadow-[0_0_30px_rgba(59,130,246,0.3)] hover:shadow-[0_0_50px_rgba(59,130,246,0.5)] hover:scale-[1.02] transition-all duration-300"
                    >
                        <Play fill="currentColor" size={14} />
                        Start 5-Minute Sequence
                    </button>
                )}

                {/* Special Scenario Buttons */}
                {(isActive || isRacing) && (
                    <>
                        <button
                            onClick={() => setShowSpecialActions(!showSpecialActions)}
                            className="w-full py-3 bg-white/5 hover:bg-white/10 border border-white/10 text-gray-400 rounded-xl text-[10px] font-black uppercase tracking-widest flex items-center justify-center gap-2 transition-all"
                        >
                            <AlertTriangle size={12} />
                            Special Scenarios
                            <ChevronDown size={12} className={`transition-transform ${showSpecialActions ? 'rotate-180' : ''}`} />
                        </button>

                        <AnimatePresence>
                            {showSpecialActions && (
                                <motion.div
                                    initial={{ opacity: 0, height: 0 }}
                                    animate={{ opacity: 1, height: 'auto' }}
                                    exit={{ opacity: 0, height: 0 }}
                                    className="grid grid-cols-2 gap-2 overflow-hidden"
                                >
                                    <button
                                        onClick={() => socket?.emit('procedure-action', { type: 'INDIVIDUAL_RECALL' })}
                                        className="py-3 bg-white/5 border border-white/10 hover:bg-accent-blue/10 hover:border-accent-blue/30 rounded-xl text-[9px] font-black uppercase transition-all flex flex-col items-center gap-2"
                                    >
                                        <FlagIcon flag="X" size={28} />
                                        <span className="text-accent-blue">Individual Recall</span>
                                    </button>
                                    <button
                                        onClick={() => socket?.emit('procedure-action', { type: 'GENERAL_RECALL' })}
                                        className="py-3 bg-white/5 border border-white/10 hover:bg-accent-cyan/10 hover:border-accent-cyan/30 rounded-xl text-[9px] font-black uppercase transition-all flex flex-col items-center gap-2"
                                    >
                                        <FlagIcon flag="FIRST_SUB" size={28} />
                                        <span className="text-accent-cyan">General Recall</span>
                                    </button>
                                    <button
                                        onClick={() => socket?.emit('procedure-action', { type: 'POSTPONE' })}
                                        className="py-3 bg-white/5 border border-white/10 hover:bg-amber-500/10 hover:border-amber-500/30 rounded-xl text-[9px] font-black uppercase transition-all flex flex-col items-center gap-2"
                                    >
                                        <FlagIcon flag="AP" size={28} />
                                        <span className="text-amber-400">Postpone</span>
                                    </button>
                                    <button
                                        onClick={() => socket?.emit('procedure-action', { type: 'ABANDON' })}
                                        className="py-3 bg-white/5 border border-white/10 hover:bg-accent-red/10 hover:border-accent-red/30 rounded-xl text-[9px] font-black uppercase transition-all flex flex-col items-center gap-2"
                                    >
                                        <FlagIcon flag="N" size={28} />
                                        <span className="text-accent-red">Abandon</span>
                                    </button>

                                    {/* AP Down / N Down Special Logic */}
                                    <div className="col-span-2 grid grid-cols-2 gap-2">
                                        {currentProcedure?.nodes?.some((n: any) => n.id === 'ap_down') && (
                                            <button
                                                onClick={() => socket?.emit('trigger-node', 'ap_down')}
                                                className="py-3 bg-amber-500/10 border border-amber-500/30 hover:bg-amber-500/20 rounded-xl text-[9px] font-black uppercase text-amber-500 transition-all flex flex-col items-center gap-1"
                                            >
                                                <div className="flex items-center gap-1">
                                                    <FlagIcon flag="AP" size={20} />
                                                    <span className="text-sm">▼</span>
                                                </div>
                                                AP DOWN (1 MIN)
                                            </button>
                                        )}
                                        {currentProcedure?.nodes?.some((n: any) => n.id === 'n_down') && (
                                            <button
                                                onClick={() => socket?.emit('trigger-node', 'n_down')}
                                                className="py-3 bg-accent-red/10 border border-accent-red/30 hover:bg-accent-red/20 rounded-xl text-[9px] font-black uppercase text-accent-red transition-all flex flex-col items-center gap-1"
                                            >
                                                <div className="flex items-center gap-1">
                                                    <FlagIcon flag="N" size={20} />
                                                    <span className="text-sm">▼</span>
                                                </div>
                                                N DOWN (1 MIN)
                                            </button>
                                        )}
                                    </div>

                                    {/* Dynamic Special Nodes from Logic Editor */}
                                    {specialNodes.filter((n: any) => n.id !== 'ap_down' && n.id !== 'n_down').map((node: any) => (
                                        <button
                                            key={node.id}
                                            onClick={() => socket?.emit('trigger-node', node.id)}
                                            className="col-span-2 py-4 bg-accent-blue/5 border border-accent-blue/20 hover:bg-accent-blue/20 hover:border-accent-blue/40 rounded-xl text-[10px] font-black uppercase transition-all flex items-center justify-between px-6 group"
                                        >
                                            <div className="flex items-center gap-4">
                                                <div className="flex gap-1">
                                                    {(node.data.flags || []).map((f: string) => (
                                                        <FlagIcon key={f} flag={f} size={24} />
                                                    ))}
                                                </div>
                                                <span className="text-white group-hover:text-accent-blue transition-colors">{node.data.label}</span>
                                            </div>
                                            <div className="text-[9px] text-accent-blue/60 font-mono italic">
                                                {node.data.duration}s
                                            </div>
                                        </button>
                                    ))}
                                </motion.div>
                            )}
                        </AnimatePresence>
                    </>
                )}

                {/* Resume from special state */}
                {isSpecial && (
                    <button
                        onClick={handleStartSequence}
                        className="w-full py-4 bg-accent-cyan hover:bg-cyan-600 text-white rounded-xl font-black uppercase tracking-[0.2em] text-xs flex items-center justify-center gap-3 shadow-lg transition-all"
                    >
                        <RotateCcw size={14} />
                        Restart Sequence
                    </button>
                )}
            </div>
        </div>
    )
}
