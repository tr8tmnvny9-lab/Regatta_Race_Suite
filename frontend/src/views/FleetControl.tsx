import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { RegattaEngine, RaceState, Team } from '@regatta/core';
import { RefreshCw, Sailboat, Settings, Plus, Users, ShieldCheck, X, Trash2 } from 'lucide-react';

export default function FleetControl({ engine, raceState }: { engine: RegattaEngine; raceState: RaceState }) {
    const [loading, setLoading] = useState(false);

    // Roster Form State
    const [isRosterFormOpen, setIsRosterFormOpen] = useState(false);
    const [newTeamName, setNewTeamName] = useState('');
    const [newClub, setNewClub] = useState('');
    const [newSkipper, setNewSkipper] = useState('');

    // Drag-and-drop state for manual overrides
    const [draggedPairingId, setDraggedPairingId] = useState<string | null>(null);

    // Local boat count (pending until saved)
    const [boatCountInput, setBoatCountInput] = useState<string>('');

    // Safely fallback structure
    const teams = Object.values((raceState as any).teams || {}) as Team[];
    const flights = Object.values((raceState as any).flights || {}).sort((a: any, b: any) => a.flightNumber - b.flightNumber) as any[];
    const pairings: any[] = (raceState as any).pairings || [];
    const settings: { mode: string; providedBoatsCount: number } = (raceState as any).fleetSettings || { mode: 'OWNER', providedBoatsCount: 6 };


    const handleModeToggle = () => {
        const newMode = settings.mode === 'OWNER' ? 'LEAGUE' : 'OWNER';
        engine.socket?.emit('update-fleet-settings', { mode: newMode, providedBoatsCount: settings.providedBoatsCount });
    };

    const handleBoatCountSave = () => {
        const count = parseInt(boatCountInput);
        if (!isNaN(count) && count >= 2) {
            engine.socket?.emit('update-fleet-settings', { mode: settings.mode, providedBoatsCount: count });
            setBoatCountInput('');
        }
    };

    const handleGenerateRotation = () => {
        setLoading(true);
        engine.socket?.emit('generate-flights', { targetRaces: 15, boats: settings.providedBoatsCount });
        setTimeout(() => setLoading(false), 800);
    };

    const handleAddTeam = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newTeamName.trim() || !newClub.trim()) return;

        const newTeam: Team = {
            id: crypto.randomUUID(),
            name: newTeamName.trim(),
            club: newClub.trim(),
            skipper: newSkipper.trim() || 'TBD',
            crewMembers: [],
            status: 'ACTIVE',
        };

        engine.socket?.emit('register-team', newTeam);
        setNewTeamName('');
        setNewClub('');
        setNewSkipper('');
        setIsRosterFormOpen(false);
    };

    const handleDeleteTeam = (teamId: string) => {
        engine.socket?.emit('delete-team', teamId);
    };

    return (
        <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="flex-1 right-sidebar p-8 overflow-y-auto space-y-8"
        >
            {/* ── Header ─────────────────────────────────────────────────────── */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-4xl font-black italic tracking-tighter uppercase drop-shadow-md">
                        Fleet <span className="text-accent-blue font-light">Management</span>
                    </h1>
                    <p className="text-gray-400 font-mono tracking-widest text-xs uppercase mt-2">
                        {settings.mode === 'LEAGUE' ? 'LEAGUE MODE — PURJEHDUSLIIGA ROTATION' : 'OWNER MODE — BYOB (BRING YOUR OWN BOAT)'}
                    </p>
                </div>

                <div className="flex gap-3 items-center">
                    {/* Boat Count Editor */}
                    <div className="flex items-center gap-2 bg-black/40 border border-white/10 rounded-xl px-3 py-2">
                        <Sailboat className="w-4 h-4 text-gray-500" />
                        <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest">BOATS</span>
                        <input
                            type="number"
                            min={2}
                            max={20}
                            value={boatCountInput !== '' ? boatCountInput : settings.providedBoatsCount}
                            onChange={e => setBoatCountInput(e.target.value)}
                            onBlur={handleBoatCountSave}
                            onKeyDown={e => e.key === 'Enter' && handleBoatCountSave()}
                            className="w-12 bg-transparent text-white font-bold text-center outline-none border-b border-white/20 focus:border-accent-blue"
                        />
                    </div>

                    <button
                        onClick={handleModeToggle}
                        className={`px-6 py-3 rounded-xl text-xs font-bold uppercase tracking-widest flex items-center gap-2 transition-all ${settings.mode === 'LEAGUE'
                            ? 'bg-accent-blue/20 border border-accent-blue/50 text-accent-blue hover:bg-accent-blue/30'
                            : 'bg-white/5 border border-white/10 text-gray-400 hover:bg-white/10 hover:text-white'
                            }`}
                    >
                        <Settings className="w-4 h-4" />
                        {settings.mode === 'LEAGUE' ? 'League Mode ON' : 'Switch to League'}
                    </button>
                </div>
            </div>

            {/* ── League Mode: Generator + Matrix ──────────────────────────── */}
            {settings.mode === 'LEAGUE' && (
                <div className="space-y-6">
                    {/* Generator Banner */}
                    <div className="p-6 rounded-2xl bg-gradient-to-r from-accent-blue/20 to-transparent border border-accent-blue/30 flex items-center justify-between gap-4">
                        <div className="flex-1">
                            <h3 className="text-xl font-bold italic tracking-tight text-white flex items-center gap-2">
                                <RefreshCw className="w-5 h-5 text-accent-blue" />
                                Fair Pairings Algorithm Engine
                            </h3>
                            <p className="text-sm text-gray-400 mt-1 leading-relaxed">
                                Cyclic-shift Latin Square — generates optimal collision-free rotations for {teams.length} teams across {settings.providedBoatsCount} provided boats.
                            </p>
                            {teams.length < settings.providedBoatsCount && (
                                <p className="text-xs text-amber-400 mt-2 flex items-center gap-1">
                                    ⚠ Need at least {settings.providedBoatsCount} teams to generate.
                                    Currently {teams.length} registered.
                                </p>
                            )}
                        </div>
                        <button
                            onClick={handleGenerateRotation}
                            disabled={loading || teams.length < settings.providedBoatsCount}
                            className={`px-8 py-4 rounded-xl font-black uppercase text-sm tracking-widest shadow-xl transition-all flex-shrink-0 ${loading || teams.length < settings.providedBoatsCount
                                ? 'bg-gray-800 text-gray-500 cursor-not-allowed'
                                : 'bg-accent-blue text-white hover:bg-blue-500 hover:scale-105 shadow-[0_0_20px_rgba(59,130,246,0.3)]'
                                }`}
                        >
                            {loading ? '⟳ Generating...' : 'Generate Rotation'}
                        </button>
                    </div>

                    {/* Flight Matrix */}
                    <div className="bg-black/40 border border-white/10 rounded-2xl overflow-hidden p-6">
                        <div className="flex items-center justify-between mb-4">
                            <h2 className="text-lg font-bold tracking-widest uppercase text-gray-300">Flight Sequence Matrix</h2>
                            <span className="text-xs font-mono text-gray-500">{flights.length} flights · {pairings.length} pairings</span>
                        </div>

                        <div className="overflow-x-auto pb-4">
                            <table className="w-full text-left border-collapse">
                                <thead>
                                    <tr>
                                        <th className="p-3 border-b border-white/5 font-mono text-xs uppercase text-gray-500 tracking-widest bg-black/60 sticky left-0 z-10 w-24">
                                            Flight
                                        </th>
                                        {Array.from({ length: settings.providedBoatsCount }).map((_, i) => (
                                            <th key={i} className="p-3 border-b border-white/5 font-bold text-sm tracking-wider text-center text-accent-cyan">
                                                Boat {i + 1}
                                            </th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {flights.map((flight: any) => {
                                        const flightPairings = pairings.filter(p => p.flightId === flight.id);
                                        return (
                                            <tr key={flight.id} className="hover:bg-white/5 transition-colors group">
                                                <td className="p-3 border-b border-white/5 bg-black/40 group-hover:bg-transparent sticky left-0 font-bold italic text-white/80 flex items-center gap-2">
                                                    <span className="text-accent-cyan/50 text-xs font-mono">#{flight.flightNumber}</span>
                                                    {flight.groupLabel || `F${flight.flightNumber}`}
                                                </td>
                                                {Array.from({ length: settings.providedBoatsCount }).map((_, i) => {
                                                    const boatId = (i + 1).toString();
                                                    const pairing = flightPairings.find(p => p.boatId === boatId);
                                                    const team = pairing ? teams.find(t => t.id === pairing.teamId) : null;
                                                    const isDragSource = pairing && pairing.id === draggedPairingId;

                                                    return (
                                                        <td
                                                            key={i}
                                                            className={`p-2 border-b border-white/5 align-middle text-center transition-colors
                                                                ${draggedPairingId && !isDragSource ? 'border-2 border-dashed border-accent-blue/30 hover:bg-accent-blue/10 cursor-alias' : ''}`}
                                                            onDragOver={e => { if (draggedPairingId) e.preventDefault(); }}
                                                            onDrop={e => {
                                                                e.preventDefault();
                                                                if (!draggedPairingId) return;
                                                                const sourcePairing = pairings.find(p => p.id === draggedPairingId);
                                                                if (!sourcePairing) return;
                                                                const newPairings = [...pairings];
                                                                if (pairing) {
                                                                    if (pairing.id === sourcePairing.id) return;
                                                                    const si = newPairings.findIndex(p => p.id === sourcePairing.id);
                                                                    const ti = newPairings.findIndex(p => p.id === pairing.id);
                                                                    const tmp = sourcePairing.teamId;
                                                                    newPairings[si] = { ...sourcePairing, teamId: pairing.teamId };
                                                                    newPairings[ti] = { ...pairing, teamId: tmp };
                                                                } else {
                                                                    const si = newPairings.findIndex(p => p.id === sourcePairing.id);
                                                                    newPairings[si] = { ...sourcePairing, flightId: flight.id, boatId };
                                                                }
                                                                engine.socket?.emit('update-pairings', newPairings);
                                                                setDraggedPairingId(null);
                                                            }}
                                                        >
                                                            {team && pairing ? (
                                                                <div
                                                                    draggable
                                                                    onDragStart={() => setDraggedPairingId(pairing.id)}
                                                                    onDragEnd={() => setDraggedPairingId(null)}
                                                                    className={`inline-block px-3 py-1.5 rounded-lg border text-xs font-bold shadow-sm cursor-grab active:cursor-grabbing transition-all
                                                                        ${isDragSource ? 'opacity-50 scale-95 border-gray-500 bg-gray-800' : 'bg-white/10 border-white/20 hover:border-accent-blue hover:text-accent-blue hover:-translate-y-0.5'}`}
                                                                    title={`${team.name} (${team.skipper})`}
                                                                >
                                                                    {team.club.toUpperCase()}
                                                                </div>
                                                            ) : (
                                                                <span className="text-gray-700 text-xs select-none">—</span>
                                                            )}
                                                        </td>
                                                    );
                                                })}
                                            </tr>
                                        );
                                    })}

                                    {flights.length === 0 && (
                                        <tr>
                                            <td colSpan={settings.providedBoatsCount + 1} className="py-12 text-center text-gray-500 font-mono text-sm">
                                                No flights generated yet. Register at least {settings.providedBoatsCount} teams then click "Generate Rotation".
                                            </td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            )}

            {/* ── Owner Mode Panel ─────────────────────────────────────────── */}
            {settings.mode === 'OWNER' && (
                <div className="p-8 border border-white/5 rounded-2xl bg-black/20">
                    <div className="flex items-start gap-6">
                        <div className="w-16 h-16 rounded-2xl bg-gray-800/60 flex items-center justify-center flex-shrink-0">
                            <Sailboat className="w-8 h-8 text-gray-500" />
                        </div>
                        <div>
                            <h2 className="text-xl font-bold uppercase tracking-widest text-white/70">Owner Mode</h2>
                            <p className="text-gray-500 mt-2 max-w-lg leading-relaxed">
                                Each helm brings their own boat. No rotation algorithm is applied. Register teams below for tracking — but
                                physical boats are statically linked. To generate fair rotation schedules, switch to League Mode.
                            </p>
                            <button
                                onClick={handleModeToggle}
                                className="mt-4 px-6 py-2 rounded-xl bg-accent-blue/10 border border-accent-blue/30 text-accent-blue text-xs font-bold tracking-widest uppercase hover:bg-accent-blue/20 transition-colors"
                            >
                                Switch to League Mode →
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* ── Team Roster ──────────────────────────────────────────────── */}
            <div className="bg-black/40 border border-white/10 rounded-2xl p-6">
                <div className="flex items-center justify-between mb-6">
                    <div className="flex items-center gap-3">
                        <Users className="w-5 h-5 text-accent-cyan" />
                        <h2 className="text-lg font-bold tracking-widest uppercase text-gray-300">
                            Registered Teams
                        </h2>
                        <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-white/5 text-gray-500">
                            {teams.length} entries
                        </span>
                    </div>
                    <button
                        onClick={() => setIsRosterFormOpen(true)}
                        className="px-4 py-2 bg-accent-cyan/20 border border-accent-cyan/50 text-accent-cyan rounded-xl text-xs font-bold uppercase tracking-widest hover:bg-accent-cyan/30 flex items-center gap-2 transition-colors"
                    >
                        <Plus className="w-4 h-4" /> Register Team
                    </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {teams.map((team: Team) => (
                        <div key={team.id} className="p-4 rounded-xl bg-white/5 border border-white/10 hover:bg-white/[0.07] transition-colors group relative">
                            <button
                                onClick={() => handleDeleteTeam(team.id)}
                                className="absolute top-3 right-3 opacity-0 group-hover:opacity-100 transition-opacity text-gray-600 hover:text-accent-red p-1 rounded-lg hover:bg-red-500/10"
                                title="Remove team"
                            >
                                <Trash2 className="w-3.5 h-3.5" />
                            </button>
                            <div className="flex justify-between items-start mb-2 pr-6">
                                <h3 className="font-bold text-white tracking-widest uppercase text-sm">{team.club}</h3>
                                <span className={`text-[9px] font-mono px-2 py-0.5 rounded-full border ${team.status === 'ACTIVE' ? 'bg-green-500/15 text-green-400 border-green-500/30' : 'bg-gray-500/15 text-gray-400 border-gray-500/30'
                                    }`}>
                                    {team.status}
                                </span>
                            </div>
                            <div className="text-xs text-gray-400 font-mono leading-relaxed">
                                <span className="text-white">{team.name}</span><br />
                                <span className="text-gray-600">Skipper:</span> {team.skipper}
                            </div>
                        </div>
                    ))}

                    {teams.length === 0 && (
                        <div className="col-span-full py-10 text-center text-gray-500 font-mono text-sm border border-dashed border-white/10 rounded-xl">
                            No teams registered. Click "Register Team" to add entries.
                        </div>
                    )}
                </div>
            </div>

            {/* ── Register Team Modal ──────────────────────────────────────── */}
            <AnimatePresence>
                {isRosterFormOpen && (
                    <div className="fixed inset-0 z-[100] flex items-center justify-center">
                        <motion.div
                            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
                            onClick={() => setIsRosterFormOpen(false)}
                        />
                        <motion.div
                            initial={{ opacity: 0, scale: 0.95, y: 10 }}
                            animate={{ opacity: 1, scale: 1, y: 0 }}
                            exit={{ opacity: 0, scale: 0.95, y: 10 }}
                            className="relative z-10 bg-[#111] border border-white/10 rounded-3xl w-[420px] shadow-2xl overflow-hidden"
                        >
                            <div className="p-4 border-b border-white/10 bg-black/40 flex justify-between items-center">
                                <h3 className="font-bold tracking-widest uppercase text-white flex items-center gap-2">
                                    <ShieldCheck className="w-4 h-4 text-accent-cyan" /> New Team Registration
                                </h3>
                                <button onClick={() => setIsRosterFormOpen(false)} className="text-gray-500 hover:text-white transition-colors">
                                    <X className="w-5 h-5" />
                                </button>
                            </div>

                            <form onSubmit={handleAddTeam} className="p-6 space-y-4">
                                {[
                                    { label: 'Club Abbreviation *', value: newClub, setter: setNewClub, placeholder: 'e.g., HSS', required: true },
                                    { label: 'Team Name / Division *', value: newTeamName, setter: setNewTeamName, placeholder: 'e.g., HSS Blue', required: true },
                                    { label: 'Skipper Name', value: newSkipper, setter: setNewSkipper, placeholder: 'Optional', required: false },
                                ].map(field => (
                                    <div key={field.label} className="space-y-1">
                                        <label className="text-[10px] font-black uppercase tracking-widest text-gray-500 pl-1">{field.label}</label>
                                        <input
                                            type="text"
                                            value={field.value}
                                            onChange={e => field.setter(e.target.value)}
                                            placeholder={field.placeholder}
                                            required={field.required}
                                            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-white font-mono placeholder:text-gray-700 outline-none focus:border-accent-cyan/50 transition-colors"
                                        />
                                    </div>
                                ))}

                                <button
                                    type="submit"
                                    className="w-full mt-4 bg-accent-cyan text-black font-black italic uppercase tracking-widest py-3 rounded-xl hover:bg-cyan-400 hover:scale-[1.02] transition-all shadow-[0_0_20px_rgba(6,182,212,0.3)]"
                                >
                                    Register Official Entry
                                </button>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </motion.div>
    );
}
