import React from 'react';
import { FlagIcon } from '../FlagIcons';
import { Flag, Info } from 'lucide-react';

const FLAG_CATALOG = [
    'CLASS', 'P', 'I', 'Z', 'U', 'BLACK', 'AP', 'X', 'N', 'FIRST_SUB'
];

const TEMPLATES = [
    {
        label: 'Warning Signal',
        duration: 60,
        flags: ['CLASS'],
        description: 'Standard 1-minute warning signal'
    },
    {
        label: 'Preparatory',
        duration: 180,
        flags: ['P'],
        description: '3-minute preparatory signal'
    },
    {
        label: 'One-Minute',
        duration: 60,
        flags: [],
        description: 'General delay or prep flag removal phase'
    },
    {
        label: 'Start',
        duration: 0,
        flags: [],
        description: 'Gun fire and class flag removal'
    },
    {
        label: 'Ongoing Comp',
        duration: 3600,
        flags: [],
        description: 'Race ongoing state'
    },
    {
        label: 'Abandonment',
        duration: 0,
        flags: ['N'],
        description: 'Immediate race abandonment'
    },
    {
        label: 'General Recall',
        duration: 60,
        flags: ['FIRST_SUB'],
        description: 'Restart sequence after general recall'
    }
];

export default function ProcedureCatalog() {
    const onDragStart = (event: React.DragEvent, nodeType: string, data: any) => {
        event.dataTransfer.setData('application/reactflow', JSON.stringify({ nodeType, data }));
        event.dataTransfer.effectAllowed = 'move';
    };

    return (
        <aside className="w-72 bg-black/40 border-r border-white/5 flex flex-col h-full backdrop-blur-md z-20">
            <div className="p-6 border-b border-white/5">
                <div className="flex items-center gap-3">
                    <Flag className="text-accent-blue" size={20} />
                    <h2 className="text-sm font-black uppercase tracking-[0.2em] text-white">Catalog</h2>
                </div>
                <p className="text-[10px] text-gray-500 mt-2 font-bold uppercase tracking-widest">Drag to add to procedure</p>
            </div>

            <div className="flex-1 overflow-y-auto custom-scrollbar p-6 space-y-8">
                {/* Flags Section */}
                <div>
                    <h3 className="text-[10px] font-black text-accent-cyan uppercase tracking-[0.3em] mb-4">Flags</h3>
                    <div className="grid grid-cols-2 gap-3">
                        {FLAG_CATALOG.map(flag => (
                            <div
                                key={flag}
                                draggable
                                onDragStart={(event) => onDragStart(event, 'state', { label: `${flag} Signal`, flags: [flag], duration: 60 })}
                                className="group p-3 bg-white/5 border border-white/10 rounded-xl hover:border-accent-blue/50 hover:bg-white/10 transition-all cursor-grab active:cursor-grabbing flex flex-col items-center gap-2"
                            >
                                <FlagIcon flag={flag} size={32} />
                                <span className="text-[8px] font-black text-gray-400 uppercase tracking-widest group-hover:text-white transition-colors">
                                    {flag}
                                </span>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Templates Section */}
                <div>
                    <h3 className="text-[10px] font-black text-accent-cyan uppercase tracking-[0.3em] mb-4">Templates</h3>
                    <div className="space-y-3">
                        {TEMPLATES.map((template, idx) => (
                            <div
                                key={idx}
                                draggable
                                onDragStart={(event) => onDragStart(event, 'state', template)}
                                className="group p-4 bg-white/5 border border-white/10 rounded-xl hover:border-accent-blue/50 hover:bg-white/10 transition-all cursor-grab active:cursor-grabbing"
                            >
                                <div className="flex items-center justify-between mb-1">
                                    <span className="text-[10px] font-black text-white uppercase tracking-widest">{template.label}</span>
                                    <span className="text-[8px] font-mono text-accent-cyan bg-accent-cyan/10 px-1 rounded">{template.duration}s</span>
                                </div>
                                <p className="text-[9px] text-gray-500 leading-relaxed">{template.description}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </div>

            <div className="p-6 border-t border-white/5 bg-black/20">
                <div className="flex items-start gap-3">
                    <Info className="text-gray-600 mt-1" size={14} />
                    <p className="text-[9px] text-gray-500 leading-relaxed italic">
                        Nodes represent race states. Connect them to define the flow of signals and timing.
                    </p>
                </div>
            </div>
        </aside>
    );
}
