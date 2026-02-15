import { Node } from 'reactflow';
import { Settings, Clock, Type, Flag, X } from 'lucide-react';
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
