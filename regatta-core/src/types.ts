// --- Core Payload Types ---

export interface Buoy {
    id: string;
    type: 'MARK' | 'START' | 'FINISH' | 'GATE';
    name: string;
    pos: { lat: number, lon: number };
    color?: string;
    rounding?: 'PORT' | 'STARBOARD';
    pairId?: string;
    gateDirection?: 'UPWIND' | 'DOWNWIND';
    design?: 'POLE' | 'BUOY' | 'TUBE' | 'MARKSETBOT';
    disableLaylines?: boolean;
}

export type RoleType = 'admin' | 'director' | 'umpire' | 'media' | 'competitor' | 'tracker';

export interface WeatherReport {
    timestamp: number;
    windDirection: number;
    windSpeed: number;
    gusts?: number;
    temperature?: number;
    provider: 'MANUAL' | 'OPENMETEO' | 'NOAA';
}

export interface LogEntry {
    id: string;
    timestamp: number;
    category: 'BOAT' | 'COURSE' | 'PROCEDURE' | 'JURY' | 'SYSTEM';
    message: string;
    details?: string;
    level?: 'info' | 'warn' | 'error';
    source?: string;
    data?: any;
    isActive?: boolean;
    protestFlagged?: boolean;
    juryNotes?: string;
}

// RRS Race Status — granular state machine
export type RaceStatusType =
    | 'IDLE'
    | 'WARNING'           // T-5:00 → T-4:00 (class flag up)
    | 'PREPARATORY'       // T-4:00 → T-1:00 (prep flag up)
    | 'ONE_MINUTE'        // T-1:00 → T-0:00 (prep flag down)
    | 'RACING'
    | 'FINISHED'
    | 'POSTPONED'         // AP flag
    | 'INDIVIDUAL_RECALL' // X flag (transient)
    | 'GENERAL_RECALL'    // 1st Substitute
    | 'ABANDONED';        // N flag

// Sound signals per RRS
export type SoundSignalType =
    | 'NONE'
    | 'ONE_SHORT'
    | 'ONE_LONG'
    | 'TWO_SHORT'
    | 'THREE_SHORT';

// Penalty types (RRS + Appendix UF)
export type PenaltyTypeValue =
    | 'OCS'
    | 'DSQ'
    | 'DNF'
    | 'DNS'
    | 'TLE'
    | 'TURN_360'
    | 'UMPIRE_NO_ACTION'
    | 'UMPIRE_PENALTY'
    | 'UMPIRE_DSQ';

export interface Penalty {
    boatId: string;
    type: PenaltyTypeValue;
    timestamp: number;
}

export interface TimeLimits {
    mark1LimitSecs?: number;
    finishWindowSecs?: number;
    tleScoring?: string;
}

// ─── Fleet & League Modes ───

export interface Team {
    id: string;
    name: string;
    club: string;
    skipper: string;
    crewMembers: string[];
    status: 'ACTIVE' | 'DNS' | 'DNF' | 'WITHDRAWN';
}

export interface Flight {
    id: string;
    flightNumber: number;
    groupLabel: string;
    status: 'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED';
}

export interface Pairing {
    id: string;
    flightId: string;
    teamId: string;
    boatId: string; // The boat token or assigned physical tracker
}

export interface FleetSettings {
    mode: 'OWNER' | 'LEAGUE';
    providedBoatsCount: number;
}

export interface RaceState {
    status: RaceStatusType;
    globalOverride?: 'AP' | 'N' | 'GENERAL_RECALL' | 'INDIVIDUAL_RECALL' | null;
    currentSequence: { event: string; flags: string[] } | null;
    sequenceTimeRemaining: number | null;
    startTime: number | null;
    wind: { direction: number, speed: number };
    weather?: WeatherReport;
    course: {
        marks: Buoy[];
        startLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        finishLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        courseBoundary: { lat: number, lon: number }[] | null;
    };
    defaultLocation?: { lat: number, lon: number, zoom: number };
    boats: Record<string, any>;
    prepFlag: string;
    currentFlags: string[];
    currentEvent: string | null;
    currentProcedure: any | null;
    currentNodeId: string | null;
    logs: LogEntry[];
    waitingForTrigger?: boolean;
    actionLabel?: string;
    isPostTrigger?: boolean;
    timeLimits?: TimeLimits;
    ocsBoats?: string[];
    penalties?: Penalty[];
    fleetHistory?: Record<string, { timestamp: number, lat: number, lon: number }[]>;
    // Fleet & League Management
    fleetSettings?: FleetSettings;
    teams?: Record<string, Team>;
    flights?: Record<string, Flight>;
    pairings?: Pairing[];
    activeFlightId?: string | null;
}
