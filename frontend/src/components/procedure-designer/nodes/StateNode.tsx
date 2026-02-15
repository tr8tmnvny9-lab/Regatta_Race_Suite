import { Handle, Position, NodeProps, useEdges } from 'reactflow';
import { FlagIcon, flagLabel } from '../../FlagIcons';
import { useState } from 'react';
import { Plus } from 'lucide-react';

export default function StateNode({ id, data, selected }: NodeProps) {
    const edges = useEdges();
    const [isHovered, setIsHovered] = useState(false);

    // Filter edges connected to this node
    const incomingEdges = edges.filter(e => e.target === id);
    const outgoingEdges = edges.filter(e => e.source === id);

    // Handle spacing configuration
    const handleSpacing = 20; // px
    const getHandlePos = (index: number, total: number) => {
        if (total <= 1) return '50%';
        // This is a bit tricky with % and px. Let's use left: calc(...)
        return `calc(50% + ${(index - (total - 1) / 2) * handleSpacing}px)`;
    };

    return (
        <div
            className={`min-w-[160px] px-4 py-3 shadow-lg rounded-xl backdrop-blur-md transition-all duration-300 relative
                ${selected
                    ? 'bg-accent-blue/20 border-2 border-accent-blue shadow-[0_0_20px_rgba(59,130,246,0.3)]'
                    : 'bg-regatta-panel/80 border border-white/10 hover:border-white/20'
                }`}
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
        >

            {/* Header */}
            <div className="flex items-center justify-between mb-2">
                <div className="font-black text-[10px] uppercase tracking-widest text-gray-300">
                    {data.label || 'State'}
                </div>
                {data.duration !== undefined && (
                    <div className="text-[9px] font-mono bg-white/10 px-1.5 py-0.5 rounded text-accent-cyan">
                        {data.duration}s
                    </div>
                )}
            </div>

            {/* Flags */}
            <div className="flex gap-2 flex-wrap min-h-[32px] items-center">
                {data.flags && data.flags.length > 0 ? (
                    data.flags.map((f: string) => (
                        <div key={f} className="relative group">
                            <FlagIcon flag={f} size={32} />
                            <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 bg-black text-[8px] rounded opacity-0 group-hover:opacity-100 whitespace-nowrap pointer-events-none transition-opacity z-50">
                                {flagLabel[f]}
                            </div>
                        </div>
                    ))
                ) : (
                    <span className="text-[9px] text-gray-600 italic">No active flags</span>
                )}
            </div>

            {/* Input Handles (Top) */}
            {incomingEdges.map((edge, idx) => (
                <Handle
                    key={edge.id}
                    type="target"
                    position={Position.Top}
                    id={edge.targetHandle || `in-${idx}`}
                    style={{ left: getHandlePos(idx, incomingEdges.length + (isHovered ? 1 : 0)) }}
                    className="!w-4 !h-4 !-top-2 !bg-accent-cyan !border-2 !border-regatta-dark hover:!scale-150 transition-transform cursor-crosshair opacity-0 hover:opacity-100"
                />
            ))}
            {/* The actual visible dots for incoming edges */}
            {incomingEdges.map((edge, idx) => (
                <div
                    key={`dot-in-${edge.id}`}
                    className="absolute -top-1 w-2 h-2 bg-accent-cyan rounded-full border border-regatta-dark pointer-events-none"
                    style={{ left: getHandlePos(idx, incomingEdges.length + (isHovered ? 1 : 0)), transform: 'translateX(-50%)' }}
                />
            ))}

            {/* "New Port" Input Handle (Top) */}
            <Handle
                type="target"
                position={Position.Top}
                id={`in-new`}
                style={{ left: getHandlePos(incomingEdges.length, incomingEdges.length + 1) }}
                className={`!w-6 !h-6 !-top-3 !bg-white/10 !border-2 !border-dashed !border-white/20 !rounded-full hover:!bg-accent-cyan transition-all cursor-crosshair flex items-center justify-center
                    ${isHovered ? 'opacity-40 hover:opacity-100 scale-100' : 'opacity-0 scale-50'}
                `}
            />

            {/* Output Handles (Bottom) */}
            {outgoingEdges.map((edge, idx) => (
                <Handle
                    key={edge.id}
                    type="source"
                    position={Position.Bottom}
                    id={edge.sourceHandle || `out-${idx}`}
                    style={{ left: getHandlePos(idx, outgoingEdges.length + 1) }}
                    className="!w-4 !h-4 !-bottom-2 !bg-accent-blue !border-2 !border-regatta-dark hover:!scale-150 transition-transform cursor-crosshair opacity-0 hover:opacity-100"
                />
            ))}
            {/* The actual visible dots for outgoing edges */}
            {outgoingEdges.map((edge, idx) => (
                <div
                    key={`dot-out-${edge.id}`}
                    className="absolute -bottom-1 w-2 h-2 bg-accent-blue rounded-full border border-regatta-dark pointer-events-none"
                    style={{ left: getHandlePos(idx, outgoingEdges.length + 1), transform: 'translateX(-50%)' }}
                />
            ))}

            {/* "New Connection" Button Handle (Bottom Center) */}
            <Handle
                type="source"
                position={Position.Bottom}
                id={`out-new`}
                style={{ left: getHandlePos(outgoingEdges.length, outgoingEdges.length + 1) }}
                className={`!w-8 !h-8 !-bottom-4 !bg-accent-blue hover:!bg-accent-cyan !border-2 !border-regatta-dark !rounded-full transition-all cursor-crosshair flex items-center justify-center shadow-lg
                    ${isHovered || outgoingEdges.length === 0 ? 'opacity-100 scale-100' : 'opacity-0 scale-50'}
                `}
            >
                <Plus size={14} className="text-white pointer-events-none" />
            </Handle>

            {/* Status Indicator (active node) */}
            {data.isActive && (
                <div className="absolute inset-0 rounded-xl border-2 border-accent-green animate-pulse pointer-events-none shadow-[0_0_30px_rgba(34,197,94,0.4)]" />
            )}
        </div>
    );
}
