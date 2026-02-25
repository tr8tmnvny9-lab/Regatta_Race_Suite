import { io, Socket } from 'socket.io-client';
import { RaceState, LogEntry } from './types';

// Encapsulates the Socket connection and State diffing architecture
export class RegattaEngine {
    public socket: Socket | null = null;
    private _stateCallback: ((state: RaceState) => void) | null = null;
    private _logsCallback: ((logs: LogEntry[]) => void) | null = null;
    private _connectionCallback: ((connected: boolean) => void) | null = null;
    private _lastState: RaceState | null = null;

    constructor(private readonly serverUrl: string, private readonly roleToken: string) { }

    get connected(): boolean {
        return this.socket?.connected || false;
    }

    connect() {
        if (this.socket) return;

        this.socket = io(this.serverUrl, {
            query: { token: this.roleToken },
            reconnection: true,
            reconnectionAttempts: Infinity,
            reconnectionDelay: 1000,
            reconnectionDelayMax: 10000,
            timeout: 10000,
        });

        this.attachListeners();
    }

    disconnect() {
        this.socket?.disconnect();
        this.socket = null;
    }

    onStateChange(cb: (state: RaceState) => void) {
        this._stateCallback = cb;
    }

    onLogsChange(cb: (logs: LogEntry[]) => void) {
        this._logsCallback = cb;
    }

    onConnectionChange(cb: (connected: boolean) => void) {
        this._connectionCallback = cb;
    }

    private pushState(state: RaceState) {
        this._lastState = state;
        if (this._stateCallback) this._stateCallback(state);
    }

    private mergeState(partial: Partial<RaceState>) {
        if (this._lastState) {
            this.pushState({ ...this._lastState, ...partial });
        }
    }

    private attachListeners() {
        if (!this.socket) return;

        // Connection lifecycle
        this.socket.on('connect', () => {
            this._connectionCallback?.(true);
            // Re-register on reconnect so server knows our role
            this.socket?.emit('register', { type: this.roleToken });
        });

        this.socket.on('disconnect', () => {
            this._connectionCallback?.(false);
        });

        this.socket.on('reconnect', () => {
            this._connectionCallback?.(true);
        });

        // Full state hydration on connect — also seeds the logs array
        this.socket.on('init-state', (state: RaceState) => {
            this.pushState(state);
            if (this._logsCallback && (state as any).logs?.length) {
                this._logsCallback((state as any).logs);
            }
        });

        // Sequence / procedure ticks — MERGE, don't replace
        // The backend sends a SequenceUpdate, not a full RaceState
        this.socket.on('sequence-update', (update: any) => {
            if (!this._lastState) return;
            this.mergeState({
                currentSequence: update.current_sequence || update.currentSequence || this._lastState.currentSequence,
                sequenceTimeRemaining: update.sequence_time_remaining ?? update.sequenceTimeRemaining ?? this._lastState.sequenceTimeRemaining,
                currentNodeId: update.current_node_id || update.currentNodeId || this._lastState.currentNodeId,
                waitingForTrigger: update.waiting_for_trigger ?? update.waitingForTrigger ?? this._lastState.waitingForTrigger,
                actionLabel: update.action_label || update.actionLabel || this._lastState.actionLabel,
                isPostTrigger: update.is_post_trigger ?? update.isPostTrigger ?? this._lastState.isPostTrigger,
                status: update.race_status || update.raceStatus || this._lastState.status,
            });
        });

        // Full state diff (fallback)
        this.socket.on('state-update', (state: RaceState) => {
            this.pushState(state);
        });

        // Boat telemetry delta — MERGE single boat into state
        this.socket.on('boat-update', (boat: any) => {
            if (!this._lastState) return;
            const boatId = boat.boat_id || boat.boatId;
            if (!boatId) return;
            const boats = { ...this._lastState.boats, [boatId]: boat };
            this.mergeState({ boats });
        });

        // Course partial updates — merge into last known state
        this.socket.on('course-updated', (course: any) => {
            if (this._lastState) {
                this.mergeState({ course });
            }
        });

        // Wind partial updates
        this.socket.on('wind-updated', (wind: any) => {
            if (this._lastState) {
                this.mergeState({ wind });
            }
        });

        // Race lifecycle events
        this.socket.on('race-started', (data: any) => {
            if (this._lastState) {
                this.mergeState({
                    status: 'RACING' as any,
                    startTime: data.startTime,
                });
            }
        });

        this.socket.on('race-finished', (data: any) => {
            if (this._lastState) {
                this.mergeState({
                    status: 'FINISHED' as any,
                });
            }
        });

        // Bulk log sync (e.g. on reconnect)
        this.socket.on('sync-logs', (logs: LogEntry[]) => {
            if (this._logsCallback) this._logsCallback(logs);
        });

        // Real-time single log entry — also merge into _lastState.logs
        this.socket.on('new-log', (log: LogEntry) => {
            if (this._lastState) {
                const logs = [...(this._lastState.logs || []), log].slice(-100);
                this._lastState = { ...this._lastState, logs };
            }
            if (this._logsCallback) this._logsCallback([log]);
        });
    }

    // --- Command Emitters ---
    emit(event: string, payload?: any) {
        this.socket?.emit(event, payload);
    }
}
