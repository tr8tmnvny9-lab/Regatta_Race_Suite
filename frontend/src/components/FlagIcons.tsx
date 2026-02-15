import React from 'react'

// ═══════════════════════════════════════════════════════════════
//  SVG FLAG COMPONENTS — Accurate ICS (International Code of Signals)
// ═══════════════════════════════════════════════════════════════

export const FlagClass = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        {/* Generic class flag — swallow-tail burgee shape, typically the club pennant */}
        <polygon points="0,0 85,0 100,35 85,70 0,70" fill="#1e40af" stroke="#fff" strokeWidth="2" />
        <polygon points="0,0 85,0 100,35 85,70 0,70" fill="url(#classGrad)" />
        <text x="38" y="44" textAnchor="middle" fill="white" fontWeight="900" fontSize="28" fontFamily="Inter, sans-serif" fontStyle="italic">C</text>
        <defs>
            <linearGradient id="classGrad" x1="0" y1="0" x2="100" y2="70">
                <stop offset="0%" stopColor="#3b82f6" />
                <stop offset="100%" stopColor="#1e3a8a" />
            </linearGradient>
        </defs>
    </svg>
)

export const FlagP = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#1e40af" stroke="#fff" strokeWidth="2" rx="2" />
        <rect x="25" y="17" width="50" height="36" fill="#ffffff" rx="1" />
    </svg>
)

export const FlagI = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#fbbf24" stroke="#fff" strokeWidth="2" rx="2" />
        <circle cx="50" cy="35" r="18" fill="#111827" />
    </svg>
)

export const FlagZ = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#111827" stroke="#fff" strokeWidth="2" rx="2" />
        <polygon points="50,35 0,0 100,0" fill="#fbbf24" />
        <polygon points="50,35 100,0 100,70" fill="#2563eb" />
        <polygon points="50,35 100,70 0,70" fill="#dc2626" />
        <polygon points="50,35 0,70 0,0" fill="#111827" />
    </svg>
)

export const FlagU = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#dc2626" stroke="#fff" strokeWidth="2" rx="2" />
        <rect x="0" y="0" width="50" height="35" fill="#ffffff" />
        <rect x="50" y="35" width="50" height="35" fill="#ffffff" />
    </svg>
)

export const FlagBlack = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#111827" stroke="#fff" strokeWidth="2" rx="2" />
        <text x="50" y="44" textAnchor="middle" fill="#fff" fontWeight="900" fontSize="18" fontFamily="Inter, sans-serif">BLK</text>
    </svg>
)

export const FlagX = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#ffffff" stroke="#666" strokeWidth="2" rx="2" />
        <rect x="37" y="0" width="26" height="70" fill="#1e40af" />
        <rect x="0" y="22" width="100" height="26" fill="#1e40af" />
    </svg>
)

export const FlagFirstSub = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <polygon points="0,0 100,35 0,70" fill="#fbbf24" stroke="#fff" strokeWidth="2" />
    </svg>
)

export const FlagAP = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#fff" stroke="#fff" strokeWidth="2" rx="2" />
        <rect x="0" y="0" width="20" height="70" fill="#dc2626" />
        <rect x="40" y="0" width="20" height="70" fill="#dc2626" />
        <rect x="80" y="0" width="20" height="70" fill="#dc2626" />
    </svg>
)

export const FlagN = ({ size = 48 }: { size?: number }) => (
    <svg width={size} height={size * 0.7} viewBox="0 0 100 70" className="drop-shadow-lg">
        <rect x="0" y="0" width="100" height="70" fill="#2563eb" stroke="#fff" strokeWidth="2" rx="2" />
        {/* Grid: 4x4 checkerboard blue/white */}
        <rect x="0" y="0" width="25" height="17.5" fill="#2563eb" />
        <rect x="25" y="0" width="25" height="17.5" fill="#ffffff" />
        <rect x="50" y="0" width="25" height="17.5" fill="#2563eb" />
        <rect x="75" y="0" width="25" height="17.5" fill="#ffffff" />
        <rect x="0" y="17.5" width="25" height="17.5" fill="#ffffff" />
        <rect x="25" y="17.5" width="25" height="17.5" fill="#2563eb" />
        <rect x="50" y="17.5" width="25" height="17.5" fill="#ffffff" />
        <rect x="75" y="17.5" width="25" height="17.5" fill="#2563eb" />
        <rect x="0" y="35" width="25" height="17.5" fill="#2563eb" />
        <rect x="25" y="35" width="25" height="17.5" fill="#ffffff" />
        <rect x="50" y="35" width="25" height="17.5" fill="#2563eb" />
        <rect x="75" y="35" width="25" height="17.5" fill="#ffffff" />
        <rect x="0" y="52.5" width="25" height="17.5" fill="#ffffff" />
        <rect x="25" y="52.5" width="25" height="17.5" fill="#2563eb" />
        <rect x="50" y="52.5" width="25" height="17.5" fill="#ffffff" />
        <rect x="75" y="52.5" width="25" height="17.5" fill="#2563eb" />
    </svg>
)

export const FlagIcon = ({ flag, size = 48 }: { flag: string, size?: number }) => {
    switch (flag) {
        case 'CLASS': return <FlagClass size={size} />
        case 'P': return <FlagP size={size} />
        case 'I': return <FlagI size={size} />
        case 'Z': return <FlagZ size={size} />
        case 'U': return <FlagU size={size} />
        case 'BLACK': return <FlagBlack size={size} />
        case 'X': return <FlagX size={size} />
        case 'FIRST_SUB': return <FlagFirstSub size={size} />
        case 'AP': return <FlagAP size={size} />
        case 'N': return <FlagN size={size} />
        default: return null
    }
}

export const flagLabel: Record<string, string> = {
    'CLASS': 'Class Flag',
    'P': 'Prep (P)',
    'I': 'Rule 30.1 (I)',
    'Z': 'Rule 30.2 (Z)',
    'U': 'Rule 30.3 (U)',
    'BLACK': 'Rule 30.4 (Black)',
    'X': 'Individual Recall',
    'FIRST_SUB': 'General Recall',
    'AP': 'Postponement',
    'N': 'Abandonment',
}
