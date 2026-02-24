import { useState, useEffect } from 'react';
import { FlagIcon } from './FlagIcons';

interface MiniTimelineProps {
    raceStatus: string;
    currentSequence: string | null;
    sequenceTimeRemaining: number | null;
    currentFlags: string[];
}

export default function MiniTimeline({
    raceStatus,
    currentSequence,
    sequenceTimeRemaining,
    currentFlags
}: MiniTimelineProps) {
    const [utcTime, setUtcTime] = useState('');

    useEffect(() => {
        const updateTime = () => {
            const now = new Date();
            setUtcTime(now.toLocaleTimeString('en-US', { hour12: false, timeZone: 'UTC' }));
        };
        updateTime();
        const interval = setInterval(updateTime, 1000);
        return () => clearInterval(interval);
    }, []);

    // Format remaining time
    const formatTime = (seconds: number) => {
        const _m = Math.floor(Math.abs(seconds) / 60);
        const _s = Math.abs(seconds) % 60;
        return `${seconds < 0 ? '-' : ''}${_m}:${_s.toString().padStart(2, '0')}`;
    };

    const isIdle = raceStatus === 'IDLE' || sequenceTimeRemaining === null;

    return (
        <div className="flex flex-col sm:flex-row items-center bg-black/80 backdrop-blur-md border border-white/10 rounded-xl px-4 py-2 gap-4 shadow-2xl">
            {/* UTC Time */}
            <div className="flex flex-col items-end border-r border-white/10 pr-4">
                <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest">
                    Live (UTC)
                </span>
                <span className="font-mono text-sm font-bold text-accent-cyan tracking-wider">
                    {utcTime}
                </span>
            </div>

            {/* Sequence Status */}
            <div className="flex flex-col min-w-[120px]">
                <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest truncate">
                    {isIdle ? 'Status' : currentSequence || raceStatus}
                </span>
                <span className={`font-mono text-lg font-black tracking-wider ${isIdle ? 'text-gray-600' : 'text-white'}`}>
                    {isIdle ? '--:--' : formatTime(sequenceTimeRemaining)}
                </span>
            </div>

            {/* Active Flags */}
            <div className="flex items-center gap-2 pl-2 border-l border-white/10 min-h-[40px]">
                {currentFlags.length === 0 ? (
                    <span className="text-[10px] font-black text-gray-600 uppercase tracking-widest">
                        No Flags
                    </span>
                ) : (
                    currentFlags.map(flag => (
                        <div key={flag} className="shrink-0 drop-shadow-lg" title={flag}>
                            <FlagIcon flag={flag} size={28} />
                        </div>
                    ))
                )}
            </div>
        </div>
    );
}
