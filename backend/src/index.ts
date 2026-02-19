import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { ProcedureEngine, ProcedureGraph } from './ProcedureEngine';

const app = express();
app.use(cors());
const httpServer = createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const PORT = process.env.PORT || 3001;

// Time Sync Endpoint (Simple NTP-like)
app.get('/sync', (req, res) => {
    res.json({ serverTime: Date.now() });
});
interface BoatState {
    pos: { lat: number, lon: number };
    imu: { heading: number, roll: number, pitch: number };
    timestamp: number;
    dtl: number;
    velocity: { speed: number, dir: number };
    lastUpdate: number;
}

interface Penalty {
    id: string;
    boatId: string;
    type: string;
    issuedAt: number;
}

interface Buoy {
    id: string;
    type: 'MARK' | 'START' | 'FINISH' | 'GATE';
    name: string;
    pos: { lat: number, lon: number };
    color?: string;
    rounding?: 'PORT' | 'STARBOARD';
    pairId?: string;
    gateDirection?: 'UPWIND' | 'DOWNWIND';
    design?: 'POLE' | 'BUOY' | 'TUBE' | 'MARKSETBOT';
}

interface RaceState {
    status: 'IDLE' | 'PRE_START' | 'RACING' | 'FINISHED' | 'POSTPONED' | 'RECALL' | 'ABANDONED';
    currentSequence: {
        event: string;
        flags: string[]; // List of active flags
    } | null;
    prepFlag: 'P' | 'I' | 'Z' | 'U' | 'BLACK';
    sequenceTimeRemaining: number | null;
    startTime: number | null;
    wind: { direction: number, speed: number };
    course: {
        marks: Buoy[];
        startLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        finishLine: { p1: { lat: number, lon: number }, p2: { lat: number, lon: number } } | null;
        courseBoundary: { lat: number, lon: number }[] | null;
    };
    currentProcedure: ProcedureGraph | null;
    defaultLocation?: { lat: number, lon: number, zoom: number };
    boats: Record<string, BoatState>;
    penalties: Penalty[];
}

const raceState: RaceState = {
    status: 'IDLE',
    currentSequence: null,
    prepFlag: 'P',
    sequenceTimeRemaining: null,
    startTime: null,
    wind: { direction: 0, speed: 0 },
    course: {
        marks: [],
        startLine: null,
        finishLine: null,
        courseBoundary: null
    },
    currentProcedure: null,
    defaultLocation: { lat: 59.3293, lon: 18.0686, zoom: 14 },
    boats: {},
    penalties: []
};

// Temporary blacklist for killed trackers to prevent ghost re-registration
const deadBoats = new Set<string>();

const STATE_FILE = path.join(__dirname, '../state.json');

const loadState = () => {
    try {
        if (fs.existsSync(STATE_FILE)) {
            const data = fs.readFileSync(STATE_FILE, 'utf8');
            const savedState = JSON.parse(data);
            Object.assign(raceState, savedState);
            raceState.boats = {};
            raceState.status = 'IDLE';
            raceState.currentSequence = null;
            raceState.sequenceTimeRemaining = null;
        }
    } catch (err) {
        console.error('Error loading state:', err);
    }
};

const saveState = () => {
    try {
        const { boats, ...persistentState } = raceState;
        fs.writeFileSync(STATE_FILE, JSON.stringify(persistentState, null, 2));
    } catch (err) {
        console.error('Error saving state:', err);
    }
};

loadState();

// --- Procedure Engine Setup ---

const procedureEngine = new ProcedureEngine((update) => {
    // Update local state
    if (update.status) raceState.status = update.status;
    if (update.currentSequence) raceState.currentSequence = update.currentSequence;
    if (update.sequenceTimeRemaining !== undefined) raceState.sequenceTimeRemaining = update.sequenceTimeRemaining;

    // Broadcast
    io.emit('sequence-update', {
        time: raceState.sequenceTimeRemaining,
        event: raceState.currentSequence?.event || '',
        flags: raceState.currentSequence?.flags || [],
        prepFlag: raceState.prepFlag,
        status: raceState.status,
        // Forward extra debug info if needed
        nodeTimeRemaining: update.nodeTimeRemaining,
        currentNodeId: update.currentNodeId
    });

    if (update.status === 'RACING' && raceState.startTime === null) {
        raceState.startTime = Date.now();
        io.emit('race-started', { startTime: raceState.startTime });
    }
});

// Global Tick for Engine
setInterval(() => {
    procedureEngine.tick();
}, 200); // 5Hz tick for better precision, though engine handles 1s logic

const createStandardGraph = (minutes: number, prepFlag: string): ProcedureGraph => {
    // Standard RRS 26: 
    // Warning (Class Up) -> Prep Up -> Prep Down -> Start
    // Warning is at `minutes` (usually 5).
    // Prep is at 4 min.
    // Prep down at 1 min.
    // Start at 0.

    // Duration calculation:
    // Warning State: 5:00 to 4:00 = 60s (if minutes=5). 
    // If minutes=10, Warning starts at 10. Warning Signal. 
    // Wait... RRS 26 says Warning is 5 min before start. 
    // If user asks for 10 min sequence? Usually means Warning is at 10? 
    // Or Warning at 5, but we wait 5 mins before? 
    // Let's assume `minutes` defines when the Warning Signal is.

    // Actually, usually "5 Minute Sequence" means Warning at 5 min.
    // "3 Minute Sequence" means Warning at 3 min.

    // Let's implement generic:
    // 1. Warning Signal (Class Up). Duration = (minutes - 4) * 60.
    //    If minutes=5, duration=60s. (5->4)
    //    If minutes=3, duration? RRS 26 is specific. 
    //    For 3 min dinghy starts: Warning (3 min), Prep (2 min), 1 min, Start.
    //    So intervals are 1 min each.

    // Let's stick to strict RRS 26 (5-4-1-0) for data.minutes >= 5.
    // If < 5, we assume 3-2-1-0.

    const nodes = [];
    let id = 1;

    // Warning Signal
    nodes.push({
        id: (id++).toString(),
        type: 'state',
        data: { label: 'Warning', flags: ['CLASS'], duration: 60 } // Standard 1 min to Prep
    });

    // Prep Signal
    nodes.push({
        id: (id++).toString(),
        type: 'state',
        data: { label: 'Preparatory', flags: ['CLASS', prepFlag], duration: 180 } // 3 mins to 1 min
    });

    // One Minute
    nodes.push({
        id: (id++).toString(),
        type: 'state',
        data: { label: 'One Minute', flags: ['CLASS'], duration: 60 } // 1 min to Start
    });

    // Start
    nodes.push({
        id: (id++).toString(),
        type: 'state',
        data: { label: 'Start', flags: [], duration: 0 }
    });

    // Edges
    const edges = [
        { id: 'e1-2', source: '1', target: '2' },
        { id: 'e2-3', source: '2', target: '3' },
        { id: 'e3-4', source: '3', target: '4' }
    ];

    // Adjust first node duration if minutes != 5?
    // If minutes=10, warning is typically at 5? No, warning at 10?
    // Let's assume user wants Warning at `minutes`.
    // So duration of first node = (minutes - 4) * 60? 
    // If minutes=5, duration=60.
    // If minutes=10, duration=360? (10->4).

    if (minutes > 4) {
        nodes[0].data.duration = (minutes - 4) * 60;
    } else if (minutes === 3) {
        // 3-minute sequence: 3(Warning)->2(Prep)->1(Down)->0(Start)
        // Node 1 (Warning): 3->2 (60s)
        // Node 2 (Prep): 2->1 (60s)
        // Node 3 (One Min): 1->0 (60s)
        nodes[0].data.duration = 60;
        nodes[1].data.duration = 60;
        nodes[2].data.duration = 60;
    }

    return { id: 'standard', nodes, edges };
};

const startRaceSequence = (minutes: number = 5, prepFlag: string = 'P') => {
    raceState.prepFlag = prepFlag as any;
    raceState.startTime = null; // Reset start time

    const graph = createStandardGraph(minutes, prepFlag);
    raceState.currentProcedure = graph;
    procedureEngine.loadProcedure(graph);
    procedureEngine.start();
};

io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);

    // Identify client type
    socket.on('register', (data) => {
        const { type, boatId } = data;
        socket.data.type = type;
        console.log(`[BACKEND] Registration: ${type} ${boatId || '(no boatId)'} from socket ${socket.id}`);
        if (type === 'tracker' && boatId) {
            socket.data.boatId = boatId;
            socket.join('trackers');
            console.log(`Boat ${boatId} registered`);
        } else if (type === 'management') {
            socket.join('management');
            console.log('Race Management registered');
        } else if (type === 'jury') {
            socket.join('jury');
            console.log('Jury registered');
        }

        // Send current state
        socket.emit('init-state', raceState);
    });

    // WebRTC Signaling
    socket.on('signal', (data) => {
        const { targetId, signal } = data;
        // Relay signal to target
        io.to(targetId).emit('signal', { senderId: socket.id, signal });
    });

    // Track Update (High Frequency)
    socket.on('track-update', (data) => {
        const boatId = socket.data.boatId;
        if (boatId) {
            if (deadBoats.has(boatId)) {
                console.log(`[BACKEND] Rejecting update from blacklisted boat ${boatId}`);
                socket.disconnect(true);
                return;
            }
            raceState.boats[boatId] = {
                ...data,
                lastUpdate: Date.now()
            };

            // Broadcast to management and jury
            socket.to('management').emit('boat-update', { boatId, ...data });
            socket.to('jury').emit('boat-update', { boatId, ...data });

            // Broadcast to media hub (with possible delay or different channel)
            io.emit('media-boat-update', { boatId, ...data });
        }
    });

    // Race Controls
    socket.on('set-race-status', (status) => {
        if (socket.data.type === 'management') {
            raceState.status = status;
            io.emit('race-status-update', status);
        }
    });

    socket.on('start-sequence', (data) => {
        if (socket.data.type === 'management') {
            const minutes = typeof data === 'object' ? (data.minutes || 5) : (data || 5);
            const prepFlag = typeof data === 'object' ? (data.prepFlag || 'P') : 'P';
            startRaceSequence(minutes, prepFlag);
        }
    });

    socket.on('set-prep-flag', (flag) => {
        if (socket.data.type === 'management') {
            raceState.prepFlag = flag;
            io.emit('state-update', raceState);
        }
    });

    socket.on('procedure-action', (action) => {
        if (socket.data.type !== 'management') return;

        switch (action.type) {
            case 'POSTPONE':
                procedureEngine.stop();
                raceState.status = 'POSTPONED';
                raceState.currentSequence = { event: 'POSTPONED', flags: ['AP'] };
                raceState.sequenceTimeRemaining = null;
                io.emit('sequence-update', { time: null, event: 'POSTPONED', flags: ['AP'], status: 'POSTPONED', prepFlag: raceState.prepFlag });
                break;
            case 'INDIVIDUAL_RECALL':
                // X flag up, sequence continues if we were in start? 
                // Usually X is up for a few minutes after start.
                // But current engine logic transitions to 'RACING' at 0.
                // If we are RACING, we just set the flag.

                // For now, just broadcast the event. The engine doesn't track X flag in standard sequence.
                raceState.currentSequence = { event: 'INDIVIDUAL_RECALL', flags: ['X'] };
                io.emit('sequence-update', { time: raceState.sequenceTimeRemaining, event: 'INDIVIDUAL_RECALL', flags: ['X'], prepFlag: raceState.prepFlag });
                break;
            case 'GENERAL_RECALL':
                procedureEngine.stop();
                raceState.status = 'RECALL';
                raceState.currentSequence = { event: 'GENERAL_RECALL', flags: ['FIRST_SUB'] };
                raceState.startTime = null;
                raceState.sequenceTimeRemaining = null;
                io.emit('sequence-update', { time: null, event: 'GENERAL_RECALL', flags: ['FIRST_SUB'], status: 'RECALL', prepFlag: raceState.prepFlag });
                break;
            case 'ABANDON':
                procedureEngine.stop();
                raceState.status = 'ABANDONED';
                raceState.currentSequence = { event: 'ABANDONED', flags: ['N'] };
                raceState.sequenceTimeRemaining = null;
                io.emit('sequence-update', { time: null, event: 'ABANDONED', flags: ['N'], status: 'ABANDONED', prepFlag: raceState.prepFlag });
                break;
        }
    });

    socket.on('save-procedure', (procedure) => {
        if (socket.data.type !== 'management') return;

        console.log('Received custom procedure:', procedure.id);

        // Stop any existing sequence
        procedureEngine.stop();

        // Load and start new procedure
        procedureEngine.loadProcedure(procedure);
        procedureEngine.start();

        // Update global state
        raceState.currentProcedure = procedure;
        raceState.status = 'PRE_START';
        raceState.startTime = null;
        // sequenceTimeRemaining will be updated by next engine tick
        saveState();
    });

    socket.on('trigger-node', (nodeId: string) => {
        if (socket.data.type !== 'management') return;
        procedureEngine.jumpToNode(nodeId);
    });

    socket.on('update-course', (course) => {
        if (socket.data.type === 'management') {
            raceState.course = course;
            io.emit('course-updated', course);
            saveState();
        }
    });

    socket.on('update-course-boundary', (boundary) => {
        if (socket.data.type === 'management') {
            raceState.course.courseBoundary = boundary;
            io.emit('course-updated', raceState.course);
            saveState();
        }
    });

    socket.on('update-wind', (wind) => {
        if (socket.data.type === 'management') {
            raceState.wind = wind;
            io.emit('wind-updated', wind);
            // Re-emit state to sync everyone
            io.emit('state-update', raceState);
            saveState();
        }
    });

    socket.on('update-default-location', (location) => {
        if (socket.data.type === 'management') {
            raceState.defaultLocation = location;
            io.emit('state-update', raceState);
            saveState();
        }
    });

    // Jury Penalties
    socket.on('issue-penalty', (data) => {
        if (socket.data.type === 'jury' || socket.data.type === 'management') {
            const penalty = {
                ...data,
                id: Math.random().toString(36).substr(2, 9),
                issuedAt: Date.now()
            };
            raceState.penalties.push(penalty);
            io.emit('penalty-issued', penalty);
        }
    });

    // Administrative Controls
    socket.on('kill-tracker', (id) => {
        console.log(`[BACKEND] kill-tracker request for "${id}". Sender type: ${socket.data.type}`);
        if (socket.data.type === 'management') {
            console.log(`Management command: Killing tracker ${id}`);

            // 1. Broadcast to all clients to update UI state immediately
            io.emit('kill-simulation', id);

            // 2. Add to blacklist to prevent ghosts (handle before disconnect)
            deadBoats.add(id);
            setTimeout(() => deadBoats.delete(id), 30000); // 30s is enough

            // 3. Find and disconnect the specific tracker socket
            const sockets = Array.from(io.sockets.sockets.values());
            let found = 0;
            sockets.forEach((s) => {
                if (s.data.boatId === id || (s.data.type === 'tracker' && s.data.boatId === id)) {
                    console.log(`Force disconnecting socket ${s.id} for boat ${id}`);
                    s.disconnect(true);
                    found++;
                }
            });
            console.log(`Disconnected ${found} sockets for boat ${id}`);

            // 4. Update local state and broadcast full sync
            if (raceState.boats[id]) {
                delete raceState.boats[id];
                io.emit('state-update', raceState);
            }
            saveState();
        } else {
            console.warn(`[BACKEND] Unauthorized kill-tracker request from ${socket.id} (${socket.data.type})`);
        }
    });

    socket.on('clear-fleet', () => {
        console.log(`[BACKEND] clear-fleet request. Sender type: ${socket.data.type}`);
        if (socket.data.type === 'management') {
            console.log('Management command: Clearing entire fleet');

            // 1. Broadcast stop signal
            io.emit('kill-simulation', 'all');

            // 2. Blacklist all current boats
            const boatIds = Object.keys(raceState.boats);
            boatIds.forEach(id => {
                deadBoats.add(id);
                setTimeout(() => deadBoats.delete(id), 30000);
            });

            // 3. Disconnect all trackers
            const sockets = Array.from(io.sockets.sockets.values());
            let count = 0;
            sockets.forEach((s) => {
                if (s.data.type === 'tracker') {
                    s.disconnect(true);
                    count++;
                }
            });
            console.log(`Disconnected ${count} tracker sockets`);

            // 4. Clear state and sync
            raceState.boats = {};
            io.emit('state-update', raceState);
            saveState();
        } else {
            console.warn(`[BACKEND] Unauthorized clear-fleet request from ${socket.id} (${socket.data.type})`);
        }
    });

    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
    });
});

httpServer.listen(PORT, () => {
    console.log(`Regatta Backend listening on port ${PORT}`);
});
