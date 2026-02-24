import { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Clock, HardDrive, Ship, Flag, Scale, Terminal, Search, Activity } from 'lucide-react';

export interface LogEntry {
    id: string;
    timestamp: number;
    category: 'BOAT' | 'COURSE' | 'PROCEDURE' | 'JURY' | 'SYSTEM';
    source: string;
    message: string;
    data?: any;
    isActive: boolean;
}

interface LogViewProps {
    logs: LogEntry[];
}

export default function LogView({ logs }: LogViewProps) {
    const [view, setView] = useState<'table' | 'timeline'>('table');
    const [filter, setFilter] = useState<string>('ALL');
    const [search, setSearch] = useState('');

    const filteredLogs = useMemo(() => {
        return logs
            .filter(l => filter === 'ALL' || l.category === filter)
            .filter(l => l.message.toLowerCase().includes(search.toLowerCase()) || l.source.toLowerCase().includes(search.toLowerCase()))
            .sort((a, b) => b.timestamp - a.timestamp);
    }, [logs, filter, search]);

    const formatTime = (ms: number) => {
        const date = new Date(ms);
        return date.toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
    };

    const getCategoryIcon = (cat: string) => {
        switch (cat) {
            case 'BOAT': return <Ship size={14} className="text-accent-blue" />;
            case 'COURSE': return <Flag size={14} className="text-accent-green" />;
            case 'PROCEDURE': return <Terminal size={14} className="text-accent-cyan" />;
            case 'JURY': return <Scale size={14} className="text-accent-red" />;
            default: return <HardDrive size={14} className="text-gray-400" />;
        }
    };

    const getCategoryColor = (cat: string) => {
        switch (cat) {
            case 'BOAT': return 'text-accent-blue bg-accent-blue/10 border-accent-blue/20';
            case 'COURSE': return 'text-accent-green bg-accent-green/10 border-accent-green/20';
            case 'PROCEDURE': return 'text-accent-cyan bg-accent-cyan/10 border-accent-cyan/20';
            case 'JURY': return 'text-accent-red bg-accent-red/10 border-accent-red/20';
            default: return 'text-gray-400 bg-gray-400/10 border-gray-400/20';
        }
    }

    return (
        <div className="flex flex-col h-full bg-regatta-dark/40 backdrop-blur-md rounded-3xl border border-white/10 overflow-hidden shadow-2xl">
            {/* Header / Controls */}
            <div className="p-6 border-b border-white/10 flex items-center justify-between gap-6">
                <div className="flex items-center gap-6">
                    <div className="flex items-center gap-3">
                        <ActivityIcon active />
                        <h2 className="text-xs font-black uppercase tracking-[0.3em] text-white">Registry Intelligence</h2>
                    </div>

                    <div className="flex bg-black/40 p-1 rounded-xl border border-white/5">
                        <button
                            onClick={() => setView('table')}
                            className={`px-4 py-1.5 rounded-lg text-[10px] font-bold uppercase transition-all ${view === 'table' ? 'bg-accent-blue text-white shadow-lg shadow-blue-900/40' : 'text-gray-500 hover:text-gray-300'}`}
                        >
                            Table
                        </button>
                        <button
                            onClick={() => setView('timeline')}
                            className={`px-4 py-1.5 rounded-lg text-[10px] font-bold uppercase transition-all ${view === 'timeline' ? 'bg-accent-blue text-white shadow-lg shadow-blue-900/40' : 'text-gray-500 hover:text-gray-300'}`}
                        >
                            Timeline
                        </button>
                    </div>
                </div>

                <div className="flex items-center gap-4 flex-1 max-w-xl">
                    <div className="relative flex-1 group">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 group-focus-within:text-accent-blue transition-colors" size={14} />
                        <input
                            type="text"
                            placeholder="Search logs..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            className="w-full bg-white/5 border border-white/10 rounded-xl py-2 pl-10 pr-4 text-[11px] text-white placeholder:text-gray-600 focus:outline-none focus:border-accent-blue/50 focus:bg-white/10 transition-all"
                        />
                    </div>

                    <div className="flex gap-2">
                        {['ALL', 'BOAT', 'COURSE', 'PROCEDURE', 'JURY', 'SYSTEM'].map(cat => (
                            <button
                                key={cat}
                                onClick={() => setFilter(cat)}
                                className={`px-3 py-2 rounded-xl text-[9px] font-black uppercase tracking-widest border transition-all ${filter === cat ? 'bg-white/10 border-white/20 text-white' : 'bg-transparent border-transparent text-gray-600 hover:text-gray-400'}`}
                            >
                                {cat}
                            </button>
                        ))}
                    </div>
                </div>
            </div>

            {/* Content Area */}
            <div className="flex-1 overflow-hidden relative">
                <AnimatePresence mode="wait">
                    {view === 'table' ? (
                        <motion.div
                            key="table"
                            initial={{ opacity: 0, x: -20 }}
                            animate={{ opacity: 1, x: 0 }}
                            exit={{ opacity: 0, x: 20 }}
                            className="h-full overflow-y-auto custom-scrollbar p-6"
                        >
                            <table className="w-full text-left border-separate border-spacing-y-2">
                                <thead className="text-[9px] font-black text-gray-600 uppercase tracking-[0.3em]">
                                    <tr>
                                        <th className="px-4 pb-2">Timestamp</th>
                                        <th className="px-4 pb-2">Category</th>
                                        <th className="px-4 pb-2">Source</th>
                                        <th className="px-4 pb-2">Event Message</th>
                                        <th className="px-4 pb-2 text-right">Status</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filteredLogs.map(log => (
                                        <tr key={log.id} className="group transition-all">
                                            <td className="bg-white/5 group-hover:bg-white/10 px-4 py-3 rounded-l-2xl border-l border-y border-white/5 group-hover:border-white/10 transition-colors">
                                                <div className="flex items-center gap-2 text-[10px] font-mono text-gray-400">
                                                    <Clock size={12} className="text-gray-600" />
                                                    {formatTime(log.timestamp)}
                                                </div>
                                            </td>
                                            <td className="bg-white/5 group-hover:bg-white/10 px-4 py-3 border-y border-white/5 group-hover:border-white/10 transition-colors">
                                                <div className={`inline-flex items-center gap-2 px-2 py-1 rounded-lg border text-[8px] font-black uppercase tracking-widest ${getCategoryColor(log.category)}`}>
                                                    {getCategoryIcon(log.category)}
                                                    {log.category}
                                                </div>
                                            </td>
                                            <td className="bg-white/5 group-hover:bg-white/10 px-4 py-3 border-y border-white/5 group-hover:border-white/10 transition-colors">
                                                <div className="text-[10px] font-bold text-white uppercase tracking-wider">{log.source}</div>
                                            </td>
                                            <td className="bg-white/5 group-hover:bg-white/10 px-4 py-3 border-y border-white/5 group-hover:border-white/10 transition-colors">
                                                <div className="text-xs text-gray-300 group-hover:text-white transition-colors">{log.message}</div>
                                            </td>
                                            <td className="bg-white/5 group-hover:bg-white/10 px-4 py-3 rounded-r-2xl border-r border-y border-white/5 group-hover:border-white/10 transition-colors text-right">
                                                <div className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[8px] font-black uppercase ${log.isActive ? 'text-accent-cyan animate-pulse' : 'text-gray-600'}`}>
                                                    <div className={`w-1.5 h-1.5 rounded-full ${log.isActive ? 'bg-accent-cyan shadow-[0_0_8px_#06b6d4]' : 'bg-gray-700'}`} />
                                                    {log.isActive ? 'Active' : 'Passive'}
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                            {filteredLogs.length === 0 && (
                                <div className="h-64 flex flex-col items-center justify-center text-gray-600 gap-4">
                                    < Terminal size={48} className="opacity-20" />
                                    <div className="text-[10px] font-black uppercase tracking-[0.4em]">No registry entries found</div>
                                </div>
                            )}
                        </motion.div>
                    ) : (
                        <motion.div
                            key="timeline"
                            initial={{ opacity: 0, scale: 0.98 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 1.02 }}
                            className="h-full p-6 flex flex-col"
                        >
                            {/* Horizontal Time Log */}
                            <div className="flex-1 overflow-x-auto overflow-y-auto custom-scrollbar">
                                <div className="min-w-[1200px] h-full relative">
                                    {/* Time grid */}
                                    <div className="absolute inset-0 flex justify-between pointer-events-none">
                                        {Array.from({ length: 12 }).map((_, i) => (
                                            <div key={i} className="h-full w-[1px] bg-white/5 border-l border-dashed border-white/5" />
                                        ))}
                                    </div>

                                    {/* Category Lanes */}
                                    <div className="relative z-10 space-y-8 py-8">
                                        {['BOAT', 'COURSE', 'PROCEDURE', 'JURY'].map(cat => {
                                            const catLogs = logs.filter(l => l.category === cat);
                                            return (
                                                <div key={cat} className="relative">
                                                    <div className="flex items-center gap-2 mb-4 px-2">
                                                        {getCategoryIcon(cat)}
                                                        <span className="text-[9px] font-black text-gray-500 uppercase tracking-[0.2em]">{cat}</span>
                                                    </div>
                                                    <div className="h-20 bg-white/5 border border-white/5 rounded-2xl relative group overflow-hidden">
                                                        {catLogs.map((log) => {
                                                            // Simple horizontal distribution for a "timeline" effect in this mock version
                                                            const left = ((log.timestamp % 1000000) / 1000000) * 80 + 10;
                                                            return (
                                                                <motion.div
                                                                    key={log.id}
                                                                    initial={{ opacity: 0, scale: 0 }}
                                                                    animate={{ opacity: 1, scale: 1 }}
                                                                    className={`absolute top-1/2 -translate-y-1/2 w-3 h-3 rounded-full cursor-pointer hover:scale-150 transition-transform group/marker ${log.isActive ? 'bg-accent-blue shadow-[0_0_15px_#3b82f6]' : 'bg-gray-500 border-2 border-white/20'}`}
                                                                    style={{ left: `${left}%` }}
                                                                    title={`${log.source}: ${log.message}`}
                                                                >
                                                                    <div className="absolute bottom-full mb-3 left-1/2 -translate-x-1/2 opacity-0 group-hover/marker:opacity-100 transition-opacity z-20 pointer-events-none whitespace-nowrap">
                                                                        <div className="bg-black/90 backdrop-blur-md border border-white/20 p-3 rounded-xl shadow-2xl">
                                                                            <div className="text-[8px] font-black text-accent-blue uppercase mb-1">{log.source}</div>
                                                                            <div className="text-[10px] text-white font-bold">{log.message}</div>
                                                                            <div className="text-[8px] text-gray-500 mt-1">{formatTime(log.timestamp)}</div>
                                                                        </div>
                                                                        <div className="w-2 h-2 bg-black/90 rotate-45 border-r border-b border-white/20 mx-auto -mt-1" />
                                                                    </div>
                                                                </motion.div>
                                                            );
                                                        })}
                                                        {/* Activity waves for active ones */}
                                                        {catLogs.some(l => l.isActive) && (
                                                            <div className="absolute inset-0 bg-gradient-to-r from-accent-blue/5 via-transparent to-transparent pointer-events-none" />
                                                        )}
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                </div>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>
        </div>
    );
}

const ActivityIcon = ({ active }: { active?: boolean }) => (
    <div className="relative w-5 h-5 flex items-center justify-center">
        <Activity size={18} className={`${active ? 'text-accent-blue' : 'text-gray-600'}`} />
        {active && (
            <motion.div
                initial={{ opacity: 0.5, scale: 0.8 }}
                animate={{ opacity: 0, scale: 1.5 }}
                transition={{ duration: 1.5, repeat: Infinity, ease: 'easeOut' }}
                className="absolute inset-0 rounded-full border border-accent-blue"
            />
        )}
    </div>
);
