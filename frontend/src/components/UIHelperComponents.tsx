import React from 'react';

export const GlassPanel = ({ title, icon: Icon, children, className = '', extraHeader }: any) => (
    <div className={`bg-regatta-panel border border-regatta-border rounded-2xl overflow-hidden shadow-2xl flex flex-col ${className}`}>
        {title && (
            <div className="bg-black/40 px-5 py-4 border-b border-white/5 flex items-center justify-between">
                <div className="flex items-center gap-3">
                    {Icon && <Icon size={16} className="text-accent-blue" />}
                    <h3 className="text-xs font-black uppercase text-gray-400 tracking-[0.2em]">{title}</h3>
                </div>
                {extraHeader && extraHeader}
            </div>
        )}
        <div className="p-5 flex-1 overflow-hidden flex flex-col">
            {children}
        </div>
    </div>
)

export const NavIcon = ({ icon: Icon, active, onClick, alert }: any) => (
    <button
        onClick={onClick}
        className={`relative w-12 h-12 mx-auto rounded-xl flex items-center justify-center transition-all duration-300 ${active ? 'bg-accent-blue/20 text-accent-blue shadow-[inset_0_0_20px_rgba(59,130,246,0.2)]' : 'text-gray-500 hover:bg-white/5 hover:text-white'}`}
    >
        <Icon size={active ? 24 : 20} className="transition-all" />
        {alert && <div className="absolute top-2 right-2 w-2 h-2 rounded-full bg-accent-red shadow-[0_0_10px_rgba(239,68,68,0.8)]" />}
    </button>
)

export const DesignerTool = ({ icon: Icon, label, active, onClick }: { icon?: any, label: string, active: boolean, onClick: () => void }) => (
    <button
        onClick={onClick}
        className={`p-3 rounded-xl border flex flex-col items-center gap-2 transition-all ${active ? 'bg-accent-blue/20 border-accent-blue/50 text-accent-blue shadow-glow-blue' : 'bg-white/5 border-white/10 text-gray-400 hover:bg-white/10 hover:text-white'}`}
    >
        {Icon && <Icon size={20} />}
        <span className="text-[10px] font-bold uppercase tracking-widest">{label}</span>
    </button>
)

export const WindControl = ({ wind, onChange, onFetchWeather, isFetching }: { wind: { direction: number, speed: number }, onChange: (w: any) => void, onFetchWeather?: () => void, isFetching?: boolean }) => {
    const [isEditing, setIsEditing] = React.useState(false);

    return (
        <GlassPanel
            title="Wind Control"
            className="pointer-events-auto"
            extraHeader={
                onFetchWeather ? (
                    <button
                        onClick={onFetchWeather}
                        disabled={isFetching}
                        className={`text-accent-cyan hover:text-white transition-colors p-1 rounded hover:bg-white/10 ${isFetching ? 'opacity-50 cursor-not-allowed animate-pulse' : ''}`}
                        title="Sync with OpenMeteo API"
                    >
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={isFetching ? "animate-spin" : ""}>
                            <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
                            <path d="M3 3v5h5" />
                            <path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
                            <path d="M16 16h5v5" />
                        </svg>
                    </button>
                ) : null
            }
        >
            <div className="flex items-center justify-between">
                <div>
                    <div className="flex items-end gap-2 mb-2">
                        <input
                            type="number"
                            value={wind.speed}
                            onChange={(e) => onChange({ ...wind, speed: Number(e.target.value) })}
                            className="bg-transparent text-5xl font-black italic tracking-tighter leading-none text-white w-24 outline-none border-b border-white/10 focus:border-blue-500 transition-colors"
                        />
                        <span className="text-sm font-bold text-gray-500 not-italic mb-1 opacity-60">KTS</span>
                    </div>
                </div>
                <div className="w-20 h-20 rounded-full border-2 border-white/10 flex items-center justify-center relative bg-white/5 shadow-inner group cursor-pointer" onClick={() => setIsEditing(!isEditing)}>
                    <span className="text-blue-500 font-bold">{wind.direction}°</span>
                </div>
            </div>
        </GlassPanel>
    )
}
