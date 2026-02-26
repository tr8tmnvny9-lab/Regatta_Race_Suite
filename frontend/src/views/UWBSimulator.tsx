// UWBSimulator.tsx
// Web control panel for the UWB Hardware Simulator
//
// Connects to the simulator's WebSocket on ws://localhost:9090/ws
// Displays:
//   - Top-down SVG 2D view of boats approaching the start line
//   - Ground truth vs estimated position per boat
//   - Real-time error statistics and network health
//   - Scenario injection controls
//   - Start/Pause/Reset/Speed controls
//
// validation_protocol.json:
//   Invariant #9 (Intuitive UX): race officers can visually verify the
//   simulator is working correctly before going on the water.

import React, { useEffect, useRef, useState, useCallback } from "react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface BoatTelemetry {
    node_id: number;
    gt_x: number;
    gt_y: number;
    gt_z: number;
    heading: number;
    heel_deg: number;
    speed_mps: number;
    is_ocs: boolean;
}

interface EstimatedPos {
    node_id: number;
    est_x: number;
    est_y: number;
    fix_quality: number;
}

interface Anchor {
    x: number;
    y: number;
}

interface Telemetry {
    type: "telemetry";
    t_to_gun: number;
    epoch: number;
    batch_mode: boolean;
    boats: BoatTelemetry[];
    estimated: EstimatedPos[];
    anchors: { mark_a: Anchor; mark_b: Anchor; committee: Anchor };
}

// ── SVG canvas dimensions ─────────────────────────────────────────────────────

const VIEW_W = 700;          // px
const VIEW_H = 500;
const WORLD_W = 200;         // meters (x: -100 to +100)
const WORLD_H = 380;         // meters (y: -350 to +30 OCS)
const ORIGIN_X = VIEW_W / 2;
const ORIGIN_Y = VIEW_H * 0.12; // start line near top

function worldToView(wx: number, wy: number): [number, number] {
    const scale = VIEW_W / WORLD_W;
    return [
        ORIGIN_X + wx * scale,
        ORIGIN_Y + (-wy) * scale,  // flip Y (boats start negative Y, move up)
    ];
}

// ── Countdown formatter ───────────────────────────────────────────────────────

function formatCountdown(secs: number): string {
    const abs = Math.abs(secs);
    const sign = secs < 0 ? "+" : "T-";
    const m = Math.floor(abs / 60);
    const s = Math.floor(abs % 60);
    return `${sign}${m}:${String(s).padStart(2, "0")}`;
}

// ── Error calculation ─────────────────────────────────────────────────────────

function calcErrors(
    boats: BoatTelemetry[],
    estimated: EstimatedPos[]
): { node_id: number; error_cm: number }[] {
    return boats.map((b) => {
        const est = estimated.find((e) => e.node_id === b.node_id);
        if (!est) return { node_id: b.node_id, error_cm: -1 };
        const err = Math.abs(b.gt_y - est.est_y) * 100;
        return { node_id: b.node_id, error_cm: err };
    });
}

// ── Main component ────────────────────────────────────────────────────────────

export default function UWBSimulator() {
    const [telem, setTelem] = useState<Telemetry | null>(null);
    const [connected, setConnected] = useState(false);
    const [speed, setSpeed] = useState(1.0);
    const [wsAddr] = useState("ws://localhost:9090/ws");
    const wsRef = useRef<WebSocket | null>(null);

    // Connect to simulator WebSocket
    useEffect(() => {
        let ws: WebSocket;
        let reconnectTimeout: ReturnType<typeof setTimeout>;

        function connect() {
            ws = new WebSocket(wsAddr);
            wsRef.current = ws;
            ws.onopen = () => { setConnected(true); };
            ws.onclose = () => {
                setConnected(false);
                reconnectTimeout = setTimeout(connect, 2000);
            };
            ws.onmessage = (evt) => {
                try {
                    const msg = JSON.parse(evt.data);
                    if (msg.type === "telemetry") setTelem(msg as Telemetry);
                } catch { /* ignore malformed */ }
            };
        }

        connect();
        return () => { ws?.close(); clearTimeout(reconnectTimeout); };
    }, [wsAddr]);

    const send = useCallback((cmd: object) => {
        wsRef.current?.send(JSON.stringify(cmd));
    }, []);

    const errors = telem ? calcErrors(telem.boats, telem.estimated) : [];
    const validErrors = errors.filter((e) => e.error_cm >= 0);
    const avgErrorCm = validErrors.length > 0
        ? validErrors.reduce((s, e) => s + e.error_cm, 0) / validErrors.length
        : 0;
    const ocsBoats = telem?.boats.filter((b) => b.gt_y > 0) ?? [];

    return (
        <div style={styles.root}>
            {/* Header */}
            <div style={styles.header}>
                <h2 style={styles.headerTitle}>📡 UWB Simulator</h2>
                <div style={styles.connBadge(connected)}>
                    {connected ? "● CONNECTED" : "● DISCONNECTED"}
                </div>
                {telem && (
                    <div style={styles.countdown(telem.t_to_gun)}>
                        {formatCountdown(telem.t_to_gun)}
                        {telem.batch_mode && (
                            <span style={styles.batchBadge}>BATCH</span>
                        )}
                    </div>
                )}
            </div>

            <div style={styles.body}>
                {/* Left: controls */}
                <div style={styles.controls}>
                    <ControlSection title="Simulation">
                        <button style={styles.btn} onClick={() => send({ cmd: "resume" })}>▶ Start</button>
                        <button style={styles.btn} onClick={() => send({ cmd: "pause" })}>⏸ Pause</button>
                        <button style={styles.btnSecondary} onClick={() => send({ cmd: "reset" })}>↺ Reset</button>
                        <div style={styles.sliderRow}>
                            <span style={styles.label}>Speed</span>
                            <input type="range" min={0.1} max={10} step={0.1} value={speed}
                                style={styles.slider}
                                onChange={(e) => {
                                    const v = parseFloat(e.target.value);
                                    setSpeed(v);
                                    send({ cmd: "set_speed", args: { speed: v } });
                                }} />
                            <span style={styles.label}>{speed.toFixed(1)}×</span>
                        </div>
                    </ControlSection>

                    <ControlSection title="Scenarios">
                        {[
                            ["default", "🔵 Normal Race"],
                            ["ocs", "🔴 OCS Boat"],
                            ["high_nlos", "📶 High NLOS"],
                            ["rough_sea", "🌊 Rough Sea"],
                            ["node_dropout", "📵 Node Dropout"],
                            ["mark_drift", "⚓ Mark Drift"],
                        ].map(([name, label]) => (
                            <button
                                key={name}
                                style={styles.scenarioBtn}
                                onClick={() => send({ cmd: "preset", args: { name } })}
                            >
                                {label}
                            </button>
                        ))}
                    </ControlSection>

                    <ControlSection title="Stats">
                        <StatRow label="Epoch" value={telem?.epoch ?? "—"} />
                        <StatRow label="Boats" value={telem?.boats.length ?? "—"} />
                        <StatRow
                            label="Avg Error"
                            value={`${avgErrorCm.toFixed(1)} cm`}
                            color={avgErrorCm < 5 ? "#4ade80" : avgErrorCm < 15 ? "#facc15" : "#f87171"}
                        />
                        <StatRow
                            label="OCS Boats"
                            value={ocsBoats.length}
                            color={ocsBoats.length > 0 ? "#f87171" : "#4ade80"}
                        />
                        <StatRow
                            label="Batch Mode"
                            value={telem?.batch_mode ? "ACTIVE" : "off"}
                            color={telem?.batch_mode ? "#facc15" : undefined}
                        />
                    </ControlSection>

                    {/* Per-boat error bars */}
                    {errors.length > 0 && (
                        <ControlSection title="Position Errors">
                            <div style={styles.errorList}>
                                {errors.map((e) => (
                                    <ErrorBar key={e.node_id} nodeId={e.node_id} errorCm={e.error_cm} />
                                ))}
                            </div>
                        </ControlSection>
                    )}
                </div>

                {/* Right: SVG view */}
                <div style={styles.canvasWrap}>
                    <svg width={VIEW_W} height={VIEW_H} style={styles.svg}>
                        <rect width={VIEW_W} height={VIEW_H} fill="#060a14" />

                        {/* Grid lines every 50m */}
                        {[-100, -50, 0, 50, 100].map((x) => {
                            const [vx] = worldToView(x, 0);
                            return <line key={x} x1={vx} y1={0} x2={vx} y2={VIEW_H} stroke="#ffffff08" strokeWidth={1} />;
                        })}
                        {[-300, -250, -200, -150, -100, -50, 0, 30].map((y) => {
                            const [_, vy] = worldToView(0, y);
                            return <line key={y} x1={0} y1={vy} x2={VIEW_W} y2={vy} stroke="#ffffff08" strokeWidth={1} />;
                        })}

                        {/* OCS zone (above line) */}
                        {(() => {
                            const [, vyOcs] = worldToView(0, 30);
                            const [, vyLine] = worldToView(0, 0);
                            return <rect x={0} y={vyOcs} width={VIEW_W} height={vyLine - vyOcs}
                                fill="#f8717108" />;
                        })()}

                        {/* Start line */}
                        {telem && (() => {
                            const [ax, ay] = worldToView(telem.anchors.mark_a.x, telem.anchors.mark_a.y);
                            const [bx, by] = worldToView(telem.anchors.mark_b.x, telem.anchors.mark_b.y);
                            return (
                                <>
                                    <line x1={ax} y1={ay} x2={bx} y2={by} stroke="#fbbf24" strokeWidth={2} />
                                    <circle cx={ax} cy={ay} r={6} fill="#fbbf24" />
                                    <text x={ax - 14} y={ay - 8} fill="#fbbf24" fontSize={9}>MarkA</text>
                                    <circle cx={bx} cy={by} r={6} fill="#fbbf24" />
                                    <text x={bx + 4} y={by - 8} fill="#fbbf24" fontSize={9}>MarkB</text>
                                    {(() => {
                                        const [cx, cy] = worldToView(telem.anchors.committee.x, telem.anchors.committee.y);
                                        return (
                                            <>
                                                <rect x={cx - 8} y={cy - 5} width={16} height={10}
                                                    fill="#60a5fa" rx={2} />
                                                <text x={cx} y={cy - 9} fill="#60a5fa" fontSize={8} textAnchor="middle">CB</text>
                                            </>
                                        );
                                    })()}
                                </>
                            );
                        })()}

                        {/* Estimated positions (transparent circle) */}
                        {telem?.estimated.map((e) => {
                            const [vx, vy] = worldToView(e.est_x, e.est_y);
                            return (
                                <circle key={`est-${e.node_id}`}
                                    cx={vx} cy={vy} r={5}
                                    fill="none" stroke="#60a5fa" strokeWidth={1} strokeDasharray="2 2"
                                    opacity={0.6}
                                />
                            );
                        })}

                        {/* Ground truth boat positions */}
                        {telem?.boats.map((b) => {
                            const [vx, vy] = worldToView(b.gt_x, b.gt_y);
                            const color = b.is_ocs ? "#f87171" : "#4ade80";
                            const hRad = (b.heading * Math.PI) / 180 - Math.PI / 2;
                            const err = errors.find((e) => e.node_id === b.node_id);
                            return (
                                <g key={b.node_id}>
                                    {/* Heading arrow */}
                                    <line
                                        x1={vx} y1={vy}
                                        x2={vx + Math.cos(hRad) * 12}
                                        y2={vy + Math.sin(hRad) * 12}
                                        stroke={color} strokeWidth={1.5} opacity={0.7}
                                    />
                                    {/* Boat marker */}
                                    <circle cx={vx} cy={vy} r={5} fill={color} fillOpacity={0.85} />
                                    {/* Node ID */}
                                    <text x={vx + 7} y={vy + 3} fill={color} fontSize={7}>{b.node_id}</text>
                                    {/* Error annotation */}
                                    {err && err.error_cm >= 0 && (
                                        <text x={vx} y={vy - 8} textAnchor="middle"
                                            fill={err.error_cm < 5 ? "#4ade80" : "#facc15"} fontSize={7}>
                                            {err.error_cm.toFixed(1)}cm
                                        </text>
                                    )}
                                </g>
                            );
                        })}

                        {/* Legend */}
                        <g transform={`translate(8, ${VIEW_H - 50})`}>
                            <circle cx={6} cy={6} r={4} fill="#4ade80" />
                            <text x={14} y={10} fill="#9ca3af" fontSize={9}>Ground truth (clear)</text>
                            <circle cx={6} cy={20} r={4} fill="#f87171" />
                            <text x={14} y={24} fill="#9ca3af" fontSize={9}>Ground truth (OCS)</text>
                            <circle cx={6} cy={34} r={4} fill="none" stroke="#60a5fa"
                                strokeWidth={1} strokeDasharray="2 2" />
                            <text x={14} y={38} fill="#9ca3af" fontSize={9}>Estimated (hub)</text>
                        </g>
                    </svg>
                </div>
            </div>
        </div>
    );
}

// ── Sub-components ────────────────────────────────────────────────────────────

function ControlSection({
    title, children
}: { title: string; children: React.ReactNode }) {
    return (
        <div style={styles.section}>
            <div style={styles.sectionTitle}>{title}</div>
            {children}
        </div>
    );
}

function StatRow({
    label, value, color
}: { label: string; value: string | number; color?: string }) {
    return (
        <div style={styles.statRow}>
            <span style={styles.statLabel}>{label}</span>
            <span style={{ ...styles.statValue, color: color ?? "#e2e8f0" }}>{value}</span>
        </div>
    );
}

function ErrorBar({ nodeId, errorCm }: { nodeId: number; errorCm: number }) {
    const pct = errorCm < 0 ? 0 : Math.min((errorCm / 30) * 100, 100);
    const color = errorCm < 3 ? "#4ade80" : errorCm < 10 ? "#facc15" : "#f87171";
    return (
        <div style={styles.errorBarRow}>
            <span style={styles.errorLabel}>#{nodeId}</span>
            <div style={styles.errorBarBg}>
                <div style={{ ...styles.errorBarFill, width: `${pct}%`, background: color }} />
            </div>
            <span style={{ ...styles.errorVal, color }}>
                {errorCm < 0 ? "—" : `${errorCm.toFixed(1)}cm`}
            </span>
        </div>
    );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = {
    root: {
        background: "#060a14",
        color: "#e2e8f0",
        minHeight: "100vh",
        fontFamily: "'Inter', sans-serif",
        display: "flex" as const,
        flexDirection: "column" as const,
    },
    header: {
        display: "flex" as const,
        alignItems: "center" as const,
        gap: 16,
        padding: "12px 20px",
        borderBottom: "1px solid #1e2d45",
        background: "#0a1120",
    },
    headerTitle: { margin: 0, fontSize: 16, fontWeight: 700, color: "#60a5fa" },
    connBadge: (ok: boolean) => ({
        fontSize: 10,
        fontWeight: 700,
        letterSpacing: "0.08em",
        color: ok ? "#4ade80" : "#f87171",
        padding: "2px 8px",
        background: ok ? "#14532d30" : "#7f1d1d30",
        borderRadius: 4,
    }),
    countdown: (t: number) => ({
        fontFamily: "monospace",
        fontSize: 22,
        fontWeight: 900,
        color: t < 0 ? "#4ade80" : t < 60 ? "#f87171" : t < 180 ? "#facc15" : "#e2e8f0",
        marginLeft: "auto",
        display: "flex" as const,
        alignItems: "center" as const,
        gap: 8,
    }),
    batchBadge: {
        fontSize: 10,
        fontWeight: 700,
        background: "#facc15",
        color: "#000",
        padding: "2px 6px",
        borderRadius: 3,
    },
    body: {
        display: "flex" as const,
        flex: 1,
        gap: 0,
    },
    controls: {
        width: 220,
        borderRight: "1px solid #1e2d45",
        padding: 12,
        overflowY: "auto" as const,
        display: "flex" as const,
        flexDirection: "column" as const,
        gap: 10,
    },
    section: {
        background: "#0d1929",
        borderRadius: 8,
        padding: 10,
        border: "1px solid #1e2d45",
    },
    sectionTitle: {
        fontSize: 9,
        fontWeight: 700,
        letterSpacing: "0.12em",
        color: "#60a5fa",
        textTransform: "uppercase" as const,
        marginBottom: 8,
    },
    btn: {
        width: "100%",
        padding: "7px 0",
        background: "#1d4ed8",
        color: "#fff",
        border: "none",
        borderRadius: 6,
        cursor: "pointer",
        fontWeight: 600,
        fontSize: 12,
        marginBottom: 4,
    },
    btnSecondary: {
        width: "100%",
        padding: "7px 0",
        background: "#1e2d45",
        color: "#94a3b8",
        border: "1px solid #334155",
        borderRadius: 6,
        cursor: "pointer",
        fontWeight: 600,
        fontSize: 12,
        marginBottom: 4,
    },
    scenarioBtn: {
        width: "100%",
        padding: "5px 6px",
        background: "#0d1929",
        color: "#94a3b8",
        border: "1px solid #1e2d45",
        borderRadius: 5,
        cursor: "pointer",
        fontSize: 11,
        textAlign: "left" as const,
        marginBottom: 3,
    },
    sliderRow: {
        display: "flex" as const,
        alignItems: "center" as const,
        gap: 6,
        marginTop: 4,
    },
    slider: { flex: 1 },
    label: { fontSize: 10, color: "#64748b", whiteSpace: "nowrap" as const },
    statRow: {
        display: "flex" as const,
        justifyContent: "space-between" as const,
        padding: "3px 0",
        borderBottom: "1px solid #1e2d4530",
    },
    statLabel: { fontSize: 10, color: "#64748b" },
    statValue: { fontSize: 11, fontWeight: 600 },
    errorList: { display: "flex" as const, flexDirection: "column" as const, gap: 4 },
    errorBarRow: { display: "flex" as const, alignItems: "center" as const, gap: 4 },
    errorLabel: { width: 24, fontSize: 9, color: "#64748b" },
    errorBarBg: {
        flex: 1, height: 5, background: "#1e2d45", borderRadius: 3, overflow: "hidden" as const,
    },
    errorBarFill: { height: "100%", borderRadius: 3, transition: "width 0.2s ease" },
    errorVal: { width: 36, fontSize: 9, textAlign: "right" as const },
    canvasWrap: {
        flex: 1,
        display: "flex" as const,
        alignItems: "flex-start" as const,
        justifyContent: "center" as const,
        padding: 16,
        overflowX: "auto" as const,
    },
    svg: { borderRadius: 8, border: "1px solid #1e2d45" },
};
