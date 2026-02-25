import { useState, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Plus, Trash2, GripVertical, Play, Save, RotateCcw, Bell, Hand, ChevronDown, ChevronUp, Flag, Volume2, Repeat } from 'lucide-react'

// ─── Types ────────────────────────────────────────────────────────────────────

type SoundSignal = 'NONE' | 'ONE_SHORT' | 'ONE_LONG' | 'TWO_SHORT' | 'THREE_SHORT'

interface ProcedureStep {
    id: string
    label: string
    duration: number       // seconds
    flags: string[]
    sound: SoundSignal
    soundOnRemove: SoundSignal
    waitForUserTrigger: boolean
    actionLabel: string
    postTriggerDuration: number
    postTriggerFlags: string[]
    raceStatus?: string   // optional explicit status override
}

interface ProcedureEditorProps {
    currentProcedure?: any
    onDeploy?: (graph: any) => void
    socket?: any
}

// ─── Sound Signal Labels ──────────────────────────────────────────────────────

const SOUND_OPTIONS: { value: SoundSignal; label: string }[] = [
    { value: 'NONE', label: 'No Sound' },
    { value: 'ONE_SHORT', label: '1 Short' },
    { value: 'ONE_LONG', label: '1 Long' },
    { value: 'TWO_SHORT', label: '2 Short' },
    { value: 'THREE_SHORT', label: '3 Short' },
]

const STATUS_OPTIONS = [
    { value: '', label: 'Auto-detect' },
    { value: 'IDLE', label: 'Idle' },
    { value: 'WARNING', label: 'Warning' },
    { value: 'PREPARATORY', label: 'Preparatory' },
    { value: 'ONE_MINUTE', label: 'One-Minute' },
    { value: 'RACING', label: 'Racing' },
    { value: 'FINISHED', label: 'Finished' },
]

// ─── Templates ────────────────────────────────────────────────────────────────

const AVAILABLE_FLAGS = ['CLASS', 'P', 'I', 'Z', 'U', 'BLACK', 'AP', 'N', 'X', 'FIRST_SUB', 'S', 'L', 'ORANGE']

const TEMPLATE_5MIN: ProcedureStep[] = [
    { id: '1', label: 'Warning Signal', duration: 60, flags: ['CLASS'], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'WARNING' },
    { id: '2', label: 'Preparatory Signal', duration: 180, flags: ['CLASS', 'P'], sound: 'ONE_SHORT', soundOnRemove: 'ONE_LONG', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'PREPARATORY' },
    { id: '3', label: 'One-Minute', duration: 60, flags: ['CLASS'], sound: 'ONE_LONG', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'ONE_MINUTE' },
    { id: '4', label: 'Start', duration: 0, flags: [], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
    { id: '5', label: 'Racing', duration: 0, flags: [], sound: 'NONE', soundOnRemove: 'NONE', waitForUserTrigger: true, actionLabel: 'FINISH RACE — End racing', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
]

const TEMPLATE_3MIN: ProcedureStep[] = [
    { id: '1', label: 'Warning Signal', duration: 60, flags: ['CLASS'], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'WARNING' },
    { id: '2', label: 'Preparatory Signal', duration: 60, flags: ['CLASS', 'P'], sound: 'ONE_SHORT', soundOnRemove: 'ONE_LONG', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'PREPARATORY' },
    { id: '3', label: 'One-Minute', duration: 60, flags: ['CLASS'], sound: 'ONE_LONG', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'ONE_MINUTE' },
    { id: '4', label: 'Start', duration: 0, flags: [], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
    { id: '5', label: 'Racing', duration: 0, flags: [], sound: 'NONE', soundOnRemove: 'NONE', waitForUserTrigger: true, actionLabel: 'FINISH RACE — End racing', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
]

const TEMPLATE_UF_LEAGUE: ProcedureStep[] = [
    { id: '1', label: 'Pre-Start Alert', duration: 0, flags: ['ORANGE'], sound: 'ONE_LONG', soundOnRemove: 'NONE', waitForUserTrigger: true, actionLabel: 'START WARNING SEQUENCE', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'IDLE' },
    { id: '2', label: 'Warning Signal', duration: 60, flags: ['CLASS'], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'WARNING' },
    { id: '3', label: 'Preparatory Signal', duration: 180, flags: ['CLASS', 'P'], sound: 'ONE_SHORT', soundOnRemove: 'ONE_LONG', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'PREPARATORY' },
    { id: '4', label: 'One-Minute', duration: 60, flags: ['CLASS'], sound: 'ONE_LONG', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'ONE_MINUTE' },
    { id: '5', label: 'Start', duration: 0, flags: [], sound: 'ONE_SHORT', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: '', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
    { id: '6', label: 'Racing (Umpired)', duration: 0, flags: [], sound: 'NONE', soundOnRemove: 'NONE', waitForUserTrigger: true, actionLabel: 'FINISH RACE — End racing', postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'RACING' },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────

function generateId(): string {
    return Math.random().toString(36).substring(2, 9)
}

function stepsToGraph(steps: ProcedureStep[], graphId: string) {
    // Always prepend an Idle node (id "0") for engine compatibility
    const nodes = [
        {
            id: '0',
            type: 'state',
            data: { label: 'Idle', flags: [], duration: 0, sound: 'NONE', soundOnRemove: 'NONE', waitForUserTrigger: false, actionLabel: null, postTriggerDuration: 0, postTriggerFlags: [], raceStatus: 'IDLE' },
        },
        ...steps.map((s, i) => ({
            id: String(i + 1),
            type: 'state',
            data: {
                label: s.label,
                flags: s.flags,
                duration: s.duration,
                sound: s.sound || 'NONE',
                soundOnRemove: s.soundOnRemove || 'NONE',
                waitForUserTrigger: s.waitForUserTrigger,
                actionLabel: s.actionLabel || null,
                postTriggerDuration: s.postTriggerDuration,
                postTriggerFlags: s.postTriggerFlags,
                raceStatus: s.raceStatus || null,
            },
        })),
    ]

    const edges = nodes.slice(0, -1).map((n, i) => ({
        id: `e${n.id}-${nodes[i + 1].id}`,
        source: n.id,
        target: nodes[i + 1].id,
        animated: true,
    }))

    return { id: graphId, nodes, edges, autoRestart: false }
}

function graphToSteps(graph: any): ProcedureStep[] {
    if (!graph?.nodes) return [...TEMPLATE_5MIN]

    // Build edge map to determine order
    const edgeMap: Record<string, string> = {}
    for (const edge of graph.edges || []) {
        edgeMap[edge.source] = edge.target
    }

    // Walk the graph from the idle node
    const ordered: any[] = []
    let current = '0' // Start at Idle
    const visited = new Set<string>()
    while (edgeMap[current] && !visited.has(current)) {
        visited.add(current)
        const nextId = edgeMap[current]
        const node = graph.nodes.find((n: any) => n.id === nextId)
        if (node) ordered.push(node)
        current = nextId
    }

    // Fallback: if walk produced nothing, just skip first node (Idle)
    const source = ordered.length > 0 ? ordered : graph.nodes.filter((n: any) => n.data?.label !== 'Idle')

    return source.map((n: any) => ({
        id: n.id || generateId(),
        label: n.data?.label || 'Step',
        duration: n.data?.duration || 0,
        flags: n.data?.flags || [],
        sound: n.data?.sound || 'NONE',
        soundOnRemove: n.data?.soundOnRemove || 'NONE',
        waitForUserTrigger: n.data?.waitForUserTrigger || false,
        actionLabel: n.data?.actionLabel || '',
        postTriggerDuration: n.data?.postTriggerDuration || 0,
        postTriggerFlags: n.data?.postTriggerFlags || [],
        raceStatus: n.data?.raceStatus || '',
    }))
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function ProcedureEditor({ currentProcedure, socket }: ProcedureEditorProps) {
    const [steps, setSteps] = useState<ProcedureStep[]>(() => graphToSteps(currentProcedure))
    const [expandedId, setExpandedId] = useState<string | null>(null)
    const [dragIdx, setDragIdx] = useState<number | null>(null)
    const [deployStatus, setDeployStatus] = useState<'idle' | 'deployed'>('idle')
    const [autoRestart, setAutoRestart] = useState(false)

    const addStep = useCallback(() => {
        setSteps(prev => [...prev, {
            id: generateId(),
            label: `Step ${prev.length + 1}`,
            duration: 60,
            flags: [],
            sound: 'ONE_SHORT',
            soundOnRemove: 'NONE',
            waitForUserTrigger: false,
            actionLabel: '',
            postTriggerDuration: 0,
            postTriggerFlags: [],
        }])
    }, [])

    const removeStep = useCallback((id: string) => {
        setSteps(prev => prev.filter(s => s.id !== id))
    }, [])

    const updateStep = useCallback((id: string, patch: Partial<ProcedureStep>) => {
        setSteps(prev => prev.map(s => s.id === id ? { ...s, ...patch } : s))
    }, [])

    const moveStep = useCallback((fromIdx: number, toIdx: number) => {
        setSteps(prev => {
            const next = [...prev]
            const [moved] = next.splice(fromIdx, 1)
            next.splice(toIdx, 0, moved)
            return next
        })
    }, [])

    const loadTemplate = useCallback((template: ProcedureStep[]) => {
        setSteps(template.map(s => ({ ...s, id: generateId() })))
        setDeployStatus('idle')
    }, [])

    const deployProcedure = useCallback(() => {
        const graph = stepsToGraph(steps, `custom-${Date.now()}`)
        const finalGraph = { ...graph, autoRestart }
        socket?.emit('save-procedure', finalGraph)
        setDeployStatus('deployed')
        setTimeout(() => setDeployStatus('idle'), 2500)
    }, [steps, socket, autoRestart])

    const toggleFlag = useCallback((stepId: string, flag: string) => {
        setSteps(prev => prev.map(s => {
            if (s.id !== stepId) return s
            const has = s.flags.includes(flag)
            return { ...s, flags: has ? s.flags.filter(f => f !== flag) : [...s.flags, flag] }
        }))
    }, [])

    const formatDuration = (secs: number) => {
        const m = Math.floor(secs / 60)
        const s = secs % 60
        return `${m}:${s.toString().padStart(2, '0')}`
    }

    const soundLabel = (s: SoundSignal) => SOUND_OPTIONS.find(o => o.value === s)?.label || 'None'

    const totalDuration = steps.reduce((acc, s) => acc + s.duration, 0)

    return (
        <div className="flex h-full">
            {/* Main Step List */}
            <div className="flex-1 flex flex-col p-6 overflow-hidden">
                {/* Header Row */}
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h3 className="text-lg font-black italic tracking-tighter uppercase text-white">Procedure Steps</h3>
                        <div className="text-[10px] font-bold text-gray-500 uppercase tracking-widest mt-1">
                            {steps.length} steps · Total: {formatDuration(totalDuration)}
                        </div>
                    </div>
                    <div className="flex gap-2">
                        <button
                            onClick={() => setAutoRestart(!autoRestart)}
                            className={`px-4 py-2.5 border rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center gap-2 ${autoRestart ? 'bg-accent-cyan/20 border-accent-cyan text-accent-cyan shadow-[0_0_15px_rgba(6,182,212,0.3)]' : 'bg-white/5 border-white/10 text-gray-400 hover:text-white hover:bg-white/10'}`}
                        >
                            <Repeat size={14} className={autoRestart ? 'animate-pulse' : ''} />
                            {autoRestart ? 'Rolling On' : 'Rolling Off'}
                        </button>
                        <button
                            onClick={addStep}
                            className="px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-[10px] font-black uppercase tracking-widest text-gray-300 hover:bg-white/10 hover:text-white transition-all flex items-center gap-2"
                        >
                            <Plus size={14} /> Add Step
                        </button>
                        <button
                            onClick={deployProcedure}
                            className={`px-6 py-2.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center gap-2 ${deployStatus === 'deployed'
                                ? 'bg-accent-green/20 border border-accent-green text-accent-green'
                                : 'bg-accent-blue border border-accent-blue text-white hover:bg-blue-600 shadow-lg shadow-accent-blue/20'
                                }`}
                        >
                            {deployStatus === 'deployed' ? (
                                <><Save size={14} /> Deployed!</>
                            ) : (
                                <><Play size={14} /> Deploy & Start</>
                            )}
                        </button>
                    </div>
                </div>

                {/* Step List */}
                <div className="flex-1 overflow-y-auto space-y-2 pr-2 custom-scrollbar">
                    <AnimatePresence initial={false}>
                        {steps.map((step, idx) => (
                            <motion.div
                                key={step.id}
                                layout
                                initial={{ opacity: 0, y: -10 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, x: -50 }}
                                className={`rounded-2xl border transition-all ${expandedId === step.id
                                    ? 'bg-white/[0.07] border-accent-blue/30'
                                    : 'bg-white/[0.03] border-white/5 hover:border-white/10'
                                    }`}
                            >
                                {/* Step Header Row */}
                                <div
                                    className="flex items-center gap-3 p-4 cursor-pointer select-none"
                                    onClick={() => setExpandedId(expandedId === step.id ? null : step.id)}
                                >
                                    {/* Drag Handle */}
                                    <div
                                        className="cursor-grab active:cursor-grabbing text-gray-600 hover:text-gray-400 transition-colors"
                                        draggable
                                        onDragStart={() => setDragIdx(idx)}
                                        onDragOver={(e) => {
                                            e.preventDefault()
                                            if (dragIdx !== null && dragIdx !== idx) {
                                                moveStep(dragIdx, idx)
                                                setDragIdx(idx)
                                            }
                                        }}
                                        onDragEnd={() => setDragIdx(null)}
                                        onClick={(e) => e.stopPropagation()}
                                    >
                                        <GripVertical size={16} />
                                    </div>

                                    {/* Step Number */}
                                    <div className="w-8 h-8 rounded-lg bg-accent-blue/20 text-accent-blue flex items-center justify-center text-xs font-black">
                                        {idx + 1}
                                    </div>

                                    {/* Step Info */}
                                    <div className="flex-1 min-w-0">
                                        <div className="text-sm font-black uppercase tracking-tight text-white truncate">{step.label}</div>
                                        <div className="text-[9px] font-bold text-gray-500 uppercase tracking-widest flex items-center gap-3">
                                            {step.duration > 0 && <span>{formatDuration(step.duration)}</span>}
                                            {step.waitForUserTrigger && <span className="text-amber-400 flex items-center gap-1"><Hand size={10} /> Manual</span>}
                                            {step.flags.length > 0 && <span className="text-accent-cyan">{step.flags.join(' + ')}</span>}
                                            {step.sound !== 'NONE' && <span className="text-purple-400 flex items-center gap-1"><Volume2 size={10} /> {soundLabel(step.sound)}</span>}
                                        </div>
                                    </div>

                                    {/* Flags Preview */}
                                    <div className="flex gap-1">
                                        {step.flags.map(f => (
                                            <div key={f} className="w-6 h-4 rounded bg-accent-blue/20 border border-accent-blue/30 flex items-center justify-center">
                                                <span className="text-[7px] font-black text-accent-blue">{f[0]}</span>
                                            </div>
                                        ))}
                                    </div>

                                    {/* Expand/Delete */}
                                    <div className="flex items-center gap-1">
                                        <button
                                            onClick={(e) => { e.stopPropagation(); removeStep(step.id) }}
                                            className="p-2 text-gray-600 hover:text-accent-red hover:bg-accent-red/10 rounded-lg transition-all"
                                        >
                                            <Trash2 size={14} />
                                        </button>
                                        {expandedId === step.id ? <ChevronUp size={14} className="text-gray-500" /> : <ChevronDown size={14} className="text-gray-500" />}
                                    </div>
                                </div>

                                {/* Expanded Details */}
                                <AnimatePresence>
                                    {expandedId === step.id && (
                                        <motion.div
                                            initial={{ height: 0, opacity: 0 }}
                                            animate={{ height: 'auto', opacity: 1 }}
                                            exit={{ height: 0, opacity: 0 }}
                                            className="overflow-hidden"
                                        >
                                            <div className="px-4 pb-4 space-y-4 border-t border-white/5 pt-4">
                                                {/* Label */}
                                                <div>
                                                    <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1">Step Label</label>
                                                    <input
                                                        type="text"
                                                        value={step.label}
                                                        onChange={e => updateStep(step.id, { label: e.target.value })}
                                                        className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors"
                                                    />
                                                </div>

                                                {/* Duration + Trigger + Status Row */}
                                                <div className="flex gap-4">
                                                    <div className="flex-1">
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1">Duration (seconds)</label>
                                                        <input
                                                            type="number"
                                                            min={0}
                                                            value={step.duration}
                                                            onChange={e => updateStep(step.id, { duration: parseInt(e.target.value) || 0 })}
                                                            className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors"
                                                        />
                                                    </div>
                                                    <div className="flex-1">
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1">Manual Trigger</label>
                                                        <button
                                                            onClick={() => updateStep(step.id, { waitForUserTrigger: !step.waitForUserTrigger })}
                                                            className={`w-full py-2.5 rounded-xl border text-[10px] font-black uppercase tracking-widest transition-all flex items-center justify-center gap-2 ${step.waitForUserTrigger
                                                                ? 'bg-amber-500/20 border-amber-500/50 text-amber-400'
                                                                : 'bg-white/5 border-white/10 text-gray-500'
                                                                }`}
                                                        >
                                                            <Hand size={12} />
                                                            {step.waitForUserTrigger ? 'Enabled' : 'Disabled'}
                                                        </button>
                                                    </div>
                                                    <div className="flex-1">
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1">Race Status</label>
                                                        <select
                                                            value={step.raceStatus || ''}
                                                            onChange={e => updateStep(step.id, { raceStatus: e.target.value || undefined })}
                                                            className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors"
                                                        >
                                                            {STATUS_OPTIONS.map(o => (
                                                                <option key={o.value} value={o.value}>{o.label}</option>
                                                            ))}
                                                        </select>
                                                    </div>
                                                </div>

                                                {/* Sound Signals Row */}
                                                <div className="flex gap-4">
                                                    <div className="flex-1">
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1 flex items-center gap-1">
                                                            <Volume2 size={10} /> Sound at Start
                                                        </label>
                                                        <select
                                                            value={step.sound}
                                                            onChange={e => updateStep(step.id, { sound: e.target.value as SoundSignal })}
                                                            className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors"
                                                        >
                                                            {SOUND_OPTIONS.map(o => (
                                                                <option key={o.value} value={o.value}>{o.label}</option>
                                                            ))}
                                                        </select>
                                                    </div>
                                                    <div className="flex-1">
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1 flex items-center gap-1">
                                                            <Volume2 size={10} /> Sound on Flag Remove
                                                        </label>
                                                        <select
                                                            value={step.soundOnRemove}
                                                            onChange={e => updateStep(step.id, { soundOnRemove: e.target.value as SoundSignal })}
                                                            className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors"
                                                        >
                                                            {SOUND_OPTIONS.map(o => (
                                                                <option key={o.value} value={o.value}>{o.label}</option>
                                                            ))}
                                                        </select>
                                                    </div>
                                                </div>

                                                {/* Action Label (only if trigger enabled) */}
                                                {step.waitForUserTrigger && (
                                                    <div>
                                                        <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-1">Action Label (shown on button)</label>
                                                        <input
                                                            type="text"
                                                            value={step.actionLabel}
                                                            onChange={e => updateStep(step.id, { actionLabel: e.target.value })}
                                                            placeholder="e.g. FIRE GUN — Advance to Racing"
                                                            className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white font-bold focus:border-accent-blue outline-none transition-colors placeholder:text-gray-700"
                                                        />
                                                    </div>
                                                )}

                                                {/* Flags */}
                                                <div>
                                                    <label className="text-[9px] font-black text-gray-500 uppercase tracking-widest block mb-2">Flags</label>
                                                    <div className="flex flex-wrap gap-1.5">
                                                        {AVAILABLE_FLAGS.map(flag => (
                                                            <button
                                                                key={flag}
                                                                onClick={() => toggleFlag(step.id, flag)}
                                                                className={`px-3 py-1.5 rounded-lg border text-[9px] font-black uppercase tracking-widest transition-all ${step.flags.includes(flag)
                                                                    ? 'bg-accent-cyan/20 border-accent-cyan/50 text-accent-cyan'
                                                                    : 'bg-white/5 border-white/10 text-gray-600 hover:text-gray-400'
                                                                    }`}
                                                            >
                                                                {flag}
                                                            </button>
                                                        ))}
                                                    </div>
                                                </div>
                                            </div>
                                        </motion.div>
                                    )}
                                </AnimatePresence>
                            </motion.div>
                        ))}
                    </AnimatePresence>

                    {steps.length === 0 && (
                        <div className="flex flex-col items-center justify-center py-20 text-center opacity-40 border-2 border-dashed border-white/10 rounded-2xl">
                            <Flag className="mb-4 text-accent-blue" size={32} />
                            <span className="text-[10px] font-bold uppercase tracking-widest">No steps defined<br />Add a step or load a template</span>
                        </div>
                    )}
                </div>
            </div>

            {/* Sidebar — Templates & Info */}
            <div className="w-72 border-l border-white/5 bg-black/20 p-6 flex flex-col gap-6 overflow-y-auto">
                <div>
                    <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-3">Templates</div>
                    <div className="space-y-2">
                        <button
                            onClick={() => loadTemplate(TEMPLATE_5MIN)}
                            className="w-full py-3 rounded-xl bg-white/5 border border-white/10 text-[10px] font-black uppercase tracking-widest text-gray-300 hover:bg-accent-blue/10 hover:border-accent-blue/30 hover:text-accent-blue transition-all flex items-center justify-center gap-2"
                        >
                            <RotateCcw size={12} /> Standard 5-Min (RRS 26)
                        </button>
                        <button
                            onClick={() => loadTemplate(TEMPLATE_3MIN)}
                            className="w-full py-3 rounded-xl bg-white/5 border border-white/10 text-[10px] font-black uppercase tracking-widest text-gray-300 hover:bg-accent-cyan/10 hover:border-accent-cyan/30 hover:text-accent-cyan transition-all flex items-center justify-center gap-2"
                        >
                            <RotateCcw size={12} /> Short Course 3-Min
                        </button>
                        <button
                            onClick={() => loadTemplate(TEMPLATE_UF_LEAGUE)}
                            className="w-full py-3 rounded-xl bg-white/5 border border-white/10 text-[10px] font-black uppercase tracking-widest text-gray-300 hover:bg-amber-500/10 hover:border-amber-500/30 hover:text-amber-400 transition-all flex items-center justify-center gap-2"
                        >
                            <RotateCcw size={12} /> League UF (Umpired)
                        </button>
                    </div>
                </div>

                <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/5">
                    <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-3">Procedure Summary</div>
                    <div className="space-y-3">
                        <div className="flex justify-between">
                            <span className="text-[9px] font-bold text-gray-500 uppercase">Total Steps</span>
                            <span className="text-xs font-black text-white">{steps.length}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-[9px] font-bold text-gray-500 uppercase">Total Time</span>
                            <span className="text-xs font-black text-accent-cyan">{formatDuration(totalDuration)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-[9px] font-bold text-gray-500 uppercase">Manual Steps</span>
                            <span className="text-xs font-black text-amber-400">{steps.filter(s => s.waitForUserTrigger).length}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-[9px] font-bold text-gray-500 uppercase">Flag Changes</span>
                            <span className="text-xs font-black text-white">{new Set(steps.flatMap(s => s.flags)).size} unique</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-[9px] font-bold text-gray-500 uppercase">Sound Events</span>
                            <span className="text-xs font-black text-purple-400">{steps.filter(s => s.sound !== 'NONE').length}</span>
                        </div>
                    </div>
                </div>

                <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/5">
                    <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2">RRS Signal Catalog</div>
                    <div className="space-y-1.5 text-[9px] text-gray-400">
                        <div className="flex justify-between"><span>Warning:</span><span className="text-white font-bold">Flag + 1 sound</span></div>
                        <div className="flex justify-between"><span>Prep:</span><span className="text-white font-bold">Flag + 1 sound</span></div>
                        <div className="flex justify-between"><span>1-Min:</span><span className="text-white font-bold">Prep ↓ + 1 long</span></div>
                        <div className="flex justify-between"><span>Start:</span><span className="text-white font-bold">Warning ↓ + 1 sound</span></div>
                        <div className="flex justify-between"><span>Recall (X):</span><span className="text-accent-cyan font-bold">X + 1 sound</span></div>
                        <div className="flex justify-between"><span>Gen Recall:</span><span className="text-accent-cyan font-bold">1st Sub + 2</span></div>
                        <div className="flex justify-between"><span>Postpone:</span><span className="text-amber-400 font-bold">AP + 2</span></div>
                        <div className="flex justify-between"><span>Abandon:</span><span className="text-accent-red font-bold">N + 3</span></div>
                    </div>
                </div>

                <div className="p-4 rounded-2xl bg-accent-blue/5 border border-accent-blue/10">
                    <div className="text-[10px] font-black text-accent-blue uppercase tracking-widest mb-2 flex items-center gap-2">
                        <Bell size={12} /> RRS 26 Engine
                    </div>
                    <p className="text-[10px] text-gray-400 leading-relaxed">
                        Steps execute top-to-bottom. Each step maps to a Race Status (Warning → Preparatory → One-Minute → Racing). Flags are raised at step start and sounds are triggered automatically.
                    </p>
                </div>
            </div>
        </div>
    )
}
