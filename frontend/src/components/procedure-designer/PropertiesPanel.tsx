import { Node } from 'reactflow';
import { Settings, Clock, Type, Flag, X, Hand } from 'lucide-react';
import { FlagIcon } from '../FlagIcons';

interface PropertiesPanelProps {
    selectedNode: Node | null;
    onUpdate: (nodeId: string, data: any) => void;
    onClose: () => void;
}

const ALL_FLAGS = [
    'CLASS', 'P', 'I', 'Z', 'U', 'BLACK', 'AP', 'X', 'N', 'FIRST_SUB'
];

export default function PropertiesPanel({ selectedNode, onUpdate, onClose }: PropertiesPanelProps) {
    if (!selectedNode) return null;

    const data = selectedNode.data;

    const handleChange = (field: string, value: any) => {
        onUpdate(selectedNode.id, { ...data, [field]: value });
    };

    const toggleFlag = (flag: string) => {
        const currentFlags = data.flags || [];
        if (currentFlags.includes(flag)) {
            handleChange('flags', currentFlags.filter((f: string) => f !== flag));
        } else {
            handleChange('flags', [...currentFlags, flag]);
        }
    };

    return (
        <aside className="w-80 bg-black/40 border-l border-white/5 flex flex-col h-full backdrop-blur-md z-20">
            <div className="p-6 border-b border-white/5 flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <Settings className="text-accent-blue" size={20} />
                    <h2 className="text-sm font-black uppercase tracking-[0.2em] text-white">Properties</h2>
                </div>
                <button onClick={onClose} className="text-gray-500 hover:text-white transition-colors">
                    <X size={18} />
                </button>
            </div>

            <div className="flex-1 overflow-y-auto custom-scrollbar p-6 space-y-8">
                {/* Node ID / Type */}
                <div className="space-y-4">
                    <div className="space-y-2">
                        <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest">
                            <Type size={12} /> Label
                        </label>
                        <input
                            type="text"
                            value={data.label || ''}
                            onChange={(e) => handleChange('label', e.target.value)}
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-xs text-white focus:outline-none focus:border-accent-blue/50 transition-all font-bold"
                            placeholder="State Label"
                        />
                    </div>

                    <div className="space-y-2">
                        <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest">
                            <Clock size={12} /> Duration (Seconds)
                        </label>
                        <input
                            type="number"
                            value={data.duration || 0}
                            onChange={(e) => handleChange('duration', parseInt(e.target.value) || 0)}
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-xs text-white focus:outline-none focus:border-accent-blue/50 transition-all font-mono"
                        />
                    </div>

                    {/* Wait for User Trigger Config */}
                    <div className="space-y-4 p-4 rounded-xl bg-white/5 border border-white/10">
                        <label className="flex items-center justify-between text-[10px] font-black text-gray-500 uppercase tracking-widest cursor-pointer">
                            <span className="flex items-center gap-2">
                                <Hand size={12} /> Halt for User Input
                            </span>
                            <input
                                type="checkbox"
                                checked={data.waitForUserTrigger || false}
                                onChange={(e) => handleChange('waitForUserTrigger', e.target.checked)}
                                className="w-4 h-4 rounded border-gray-600 accent-accent-blue"
                            />
                        </label>

                        {data.waitForUserTrigger && (
                            <div className="space-y-4 mt-3 pt-3 border-t border-white/10">
                                <div className="space-y-2">
                                    <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest">
                                        <Type size={12} /> Action Button Label
                                    </label>
                                    <input
                                        type="text"
                                        value={data.actionLabel || ''}
                                        onChange={(e) => handleChange('actionLabel', e.target.value)}
                                        className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-accent-blue/50 transition-all font-bold"
                                        placeholder="e.g., TAKE AP DOWN"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest">
                                        <Clock size={12} /> Post-Trigger Duration
                                    </label>
                                    <input
                                        type="number"
                                        value={data.postTriggerDuration || 0}
                                        onChange={(e) => handleChange('postTriggerDuration', parseInt(e.target.value) || 0)}
                                        className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-accent-blue/50 transition-all font-mono"
                                        title="Seconds this block should countdown AFTER trigger is pressed before advancing"
                                    />
                                    <p className="text-[9px] text-gray-500 mt-1 leading-tight">Time to countdown internally after triggering before transitioning to next node.</p>
                                </div>

                                <div className="space-y-2">
                                    <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest space-x-2">
                                        <Flag size={12} /> Post-Trigger Flags
                                    </label>
                                    <div className="flex gap-2">
                                        <input
                                            type="text"
                                            placeholder="Add flag (e.g. AP)"
                                            onKeyDown={(e) => {
                                                if (e.key === 'Enter' && e.currentTarget.value) {
                                                    const newFlags = [...(data.postTriggerFlags || []), e.currentTarget.value];
                                                    handleChange('postTriggerFlags', newFlags);
                                                    e.currentTarget.value = '';
                                                }
                                            }}
                                            className="flex-1 bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-accent-blue/50 transition-all font-bold"
                                        />
                                    </div>
                                    <div className="flex flex-wrap gap-2 mt-2">
                                        {(data.postTriggerFlags || []).map((flag: string, i: number) => (
                                            <div key={i} className="bg-white/10 px-2 py-1 rounded text-[10px] font-bold text-white flex items-center gap-1 group">
                                                {flag}
                                                <button
                                                    onClick={() => handleChange('postTriggerFlags', data.postTriggerFlags.filter((_: any, idx: number) => idx !== i))}
                                                    className="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-300 transition-opacity"
                                                >
                                                    ×
                                                </button>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Flags Selector */}
                <div>
                    <label className="flex items-center gap-2 text-[10px] font-black text-gray-500 uppercase tracking-widest mb-4">
                        <Flag size={12} /> Active Flags
                    </label>
                    <div className="grid grid-cols-2 gap-2">
                        {ALL_FLAGS.map(flag => {
                            const isActive = (data.flags || []).includes(flag);
                            return (
                                <button
                                    key={flag}
                                    onClick={() => toggleFlag(flag)}
                                    className={`flex items-center gap-2 p-2 rounded-xl border transition-all text-left
                                        ${isActive
                                            ? 'bg-accent-blue/20 border-accent-blue/50 text-white'
                                            : 'bg-white/5 border-white/10 text-gray-500 hover:border-white/20'}`}
                                >
                                    <FlagIcon flag={flag} size={24} />
                                    <span className="text-[8px] font-black uppercase tracking-widest whitespace-nowrap overflow-hidden text-ellipsis">
                                        {flag}
                                    </span>
                                </button>
                            );
                        })}
                    </div>
                </div>
            </div>

            <div className="p-6 border-t border-white/5 bg-black/20">
                <p className="text-[9px] text-gray-600 leading-relaxed font-bold uppercase tracking-widest text-center">
                    Node: {selectedNode.id} • Type: {selectedNode.type}
                </p>
            </div>
        </aside>
    );
}
