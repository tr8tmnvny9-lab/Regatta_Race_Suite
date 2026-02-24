import React, { useCallback, useRef, useState } from 'react';
import ReactFlow, {
    Background,
    Controls,
    useNodesState,
    useEdgesState,
    addEdge,
    Connection,
    Edge,
    Node,
    ReactFlowProvider,
    useReactFlow,
    MarkerType,
    ConnectionLineType,
} from 'reactflow';
import { io, Socket } from 'socket.io-client';
import 'reactflow/dist/style.css';
import StateNode from './nodes/StateNode';
import ProcedureCatalog from './ProcedureCatalog';
import PropertiesPanel from './PropertiesPanel';
import { Save, Plus, Play } from 'lucide-react';

const nodeTypes = {
    state: StateNode,
};

const initialNodes: Node[] = [
    {
        id: '0',
        type: 'state',
        position: { x: 250, y: -100 },
        data: { label: 'Idle', flags: [], duration: 0 }
    },
    {
        id: '1',
        type: 'state',
        position: { x: 250, y: 50 },
        data: { label: 'Warning Signal', flags: ['CLASS'], duration: 60 }
    },
    {
        id: '2',
        type: 'state',
        position: { x: 250, y: 200 },
        data: { label: 'Preparatory Signal', flags: ['CLASS', 'P'], duration: 180 }
    },
    {
        id: '3',
        type: 'state',
        position: { x: 250, y: 350 },
        data: { label: 'One-Minute', flags: ['CLASS'], duration: 60 }
    },
    {
        id: '4',
        type: 'state',
        position: { x: 250, y: 500 },
        data: { label: 'Start', flags: [], duration: 0 }
    },
    {
        id: '5',
        type: 'state',
        position: { x: 250, y: 650 },
        data: { label: 'Racing', flags: [], duration: 3600 }
    },
    // Special Nodes (Floating)
    {
        id: 'ap_down',
        type: 'state',
        position: { x: 600, y: 200 },
        data: { label: 'AP Down', flags: [], duration: 60, description: '1 minute to Warning Signal' }
    },
    {
        id: 'n_down',
        type: 'state',
        position: { x: 600, y: 350 },
        data: { label: 'N Down', flags: [], duration: 60, description: '1 minute to Warning Signal' }
    },
];

const initialEdges: Edge[] = [
    {
        id: 'e0-1', source: '0', target: '1', sourceHandle: 'out-0', targetHandle: 'in-0', animated: true,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
    },
    {
        id: 'e1-2', source: '1', target: '2', sourceHandle: 'out-0', targetHandle: 'in-0', animated: true,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
    },
    {
        id: 'e2-3', source: '2', target: '3', sourceHandle: 'out-0', targetHandle: 'in-0', animated: true,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
    },
    {
        id: 'e3-4', source: '3', target: '4', sourceHandle: 'out-0', targetHandle: 'in-0', animated: true,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
    },
    {
        id: 'e4-5', source: '4', target: '5', sourceHandle: 'out-0', targetHandle: 'in-0', animated: true,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
    },
    // Suggested recovery paths from special signals
    {
        id: 'e_ap-1', source: 'ap_down', target: '1', sourceHandle: 'out-0', targetHandle: 'in-0',
        style: { stroke: '#94a3b8', strokeWidth: 2, strokeDasharray: '5,5' },
        markerEnd: { type: MarkerType.ArrowClosed, color: '#94a3b8' }
    },
    {
        id: 'e_n-1', source: 'n_down', target: '1', sourceHandle: 'out-0', targetHandle: 'in-0',
        style: { stroke: '#94a3b8', strokeWidth: 2, strokeDasharray: '5,5' },
        markerEnd: { type: MarkerType.ArrowClosed, color: '#94a3b8' }
    },
];

const STANDARD_STEPS = [
    'Idle',
    'Warning Signal',
    'Preparatory Signal',
    'One-Minute',
    'Start',
    'Racing'
];

const getEdgeStyle = (sourceNode: Node | undefined, targetNode: Node | undefined) => {
    const defaultStyle = {
        stroke: '#94a3b8',
        strokeWidth: 2,
        strokeDasharray: '5,5',
        animated: false,
        markerEnd: { type: MarkerType.ArrowClosed, color: '#94a3b8' } as any
    };

    if (!sourceNode || !targetNode) return defaultStyle;

    const sourceLabel = sourceNode.data.label;
    const targetLabel = targetNode.data.label;

    const sourceIdx = STANDARD_STEPS.indexOf(sourceLabel);
    const targetIdx = STANDARD_STEPS.indexOf(targetLabel);

    // If both are standard and target is the direct successor
    if (sourceIdx !== -1 && targetIdx !== -1 && targetIdx === sourceIdx + 1) {
        return {
            stroke: '#06b6d4',
            strokeWidth: 3,
            strokeDasharray: '0',
            animated: true,
            markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' } as any
        };
    }

    // Otherwise dotted/dashed for special scenarios
    return defaultStyle;
};

function DesignerInner({ currentProcedure }: { currentProcedure: any }) {
    const reactFlowWrapper = useRef<HTMLDivElement>(null);
    // Sanitize nodes before passing to useNodesState to prevent ReactFlow crash
    const sanitizedInitialNodes = React.useMemo(() => {
        const rawNodes = currentProcedure?.nodes || initialNodes;
        return rawNodes.map((n: any, idx: number) => ({
            ...n,
            position: n.position || { x: 250, y: idx * 150 + 50 }
        }));
    }, [currentProcedure]);

    const [nodes, setNodes, onNodesChange] = useNodesState(sanitizedInitialNodes);
    const [edges, setEdges, onEdgesChange] = useEdgesState(currentProcedure?.edges || initialEdges);
    const [socket, setSocket] = useState<Socket | null>(null);
    const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
    const [reactFlowInstance, setReactFlowInstance] = useState<any>(null);
    const connectingNodeId = useRef<string | null>(null);

    // Use a hook to get the project function, but handle it being unavailable
    const rf = useReactFlow();

    // Handle Escape key to cancel connection (Deselect)
    React.useEffect(() => {
        const handleKeyDown = (event: KeyboardEvent) => {
            if (event.key === 'Escape') {
                setSelectedNodeId(null);
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);


    React.useEffect(() => {
        const s = io('http://localhost:3001');
        setSocket(s);

        s.on('connect', () => {
            s.emit('register', { type: 'management' });
        });

        s.on('sequence-update', (data: any) => {
            const activeId = data.currentNodeId || data.activeStepId;

            setNodes((nds) => nds.map((node) => ({
                ...node,
                data: {
                    ...node.data,
                    isActive: node.id === activeId || node.data.label === data.currentLabel
                }
            })));
        });

        return () => {
            s.disconnect();
        };
    }, [setNodes]);

    const onConnect = useCallback(
        (params: Connection) => {
            const sourceNode = nodes.find(n => n.id === params.source);
            const targetNode = nodes.find(n => n.id === params.target);
            const style = getEdgeStyle(sourceNode, targetNode);

            setEdges((eds) => addEdge({
                ...params,
                animated: style.animated,
                style: { stroke: style.stroke, strokeWidth: style.strokeWidth, strokeDasharray: style.strokeDasharray },
                markerEnd: style.markerEnd
            }, eds));
        },
        [setEdges, nodes],
    );

    const onConnectStart = useCallback((_: any, { nodeId }: any) => {
        connectingNodeId.current = nodeId;
    }, []);

    const onConnectEnd = useCallback(
        (event: any) => {
            const targetIsPane = event.target.classList.contains('react-flow__pane');

            if (targetIsPane && connectingNodeId.current && rf) {
                const { top, left } = reactFlowWrapper.current!.getBoundingClientRect();
                const id = (nodes.length + 20).toString(); // Use a higher ID to avoid collision

                const newNode: Node = {
                    id,
                    type: 'state',
                    position: rf.project({
                        x: event.clientX - left,
                        y: event.clientY - top,
                    }),
                    data: { label: `New State ${id}`, flags: [], duration: 60 },
                };

                setNodes((nds) => nds.concat(newNode));

                const sourceNode = nodes.find(n => n.id === connectingNodeId.current);
                const style = getEdgeStyle(sourceNode, newNode);

                setEdges((eds) =>
                    eds.concat({
                        id: `e${connectingNodeId.current}-${id}`,
                        source: connectingNodeId.current!,
                        target: id,
                        sourceHandle: 'out-new',
                        targetHandle: 'in-new',
                        animated: style.animated,
                        style: { stroke: style.stroke, strokeWidth: style.strokeWidth, strokeDasharray: style.strokeDasharray },
                        markerEnd: style.markerEnd
                    })
                );
            }
        },
        [rf, nodes, setNodes, setEdges]
    );

    const onNodeClick = useCallback((_event: React.MouseEvent, node: Node) => {
        setSelectedNodeId(node.id);
    }, []);

    const onPaneClick = useCallback(() => {
        setSelectedNodeId(null);
    }, []);

    const onNodeUpdate = useCallback((nodeId: string, newData: any) => {
        setNodes((nds) => nds.map((node) =>
            node.id === nodeId ? { ...node, data: newData } : node
        ));
    }, [setNodes]);

    const onDragOver = useCallback((event: React.DragEvent) => {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }, []);

    const onDrop = useCallback(
        (event: React.DragEvent) => {
            event.preventDefault();

            const reactFlowBounds = reactFlowWrapper.current?.getBoundingClientRect();
            const typeDataString = event.dataTransfer.getData('application/reactflow');

            if (!typeDataString || !reactFlowBounds || !reactFlowInstance) return;

            const { nodeType, data } = JSON.parse(typeDataString);
            const position = reactFlowInstance.project({
                x: event.clientX - reactFlowBounds.left,
                y: event.clientY - reactFlowBounds.top,
            });

            const newNode: Node = {
                id: (nodes.length + 1).toString(),
                type: nodeType,
                position,
                data: data,
            };

            setNodes((nds) => nds.concat(newNode));
            setSelectedNodeId(newNode.id);
        },
        [reactFlowInstance, nodes, setNodes]
    );

    const addNode = useCallback(() => {
        const id = (nodes.length + 1).toString();
        const newNode: Node = {
            id,
            type: 'state',
            position: { x: 250, y: nodes.length > 0 ? nodes[nodes.length - 1].position.y + 150 : 50 },
            data: { label: `New State ${id}`, flags: [], duration: 60 },
        };
        setNodes((nds) => nds.concat(newNode));
        setSelectedNodeId(id);
    }, [nodes, setNodes]);

    const saveProcedure = useCallback((deploy: boolean = false) => {
        if (!socket) return;

        const procedure = {
            id: 'custom-' + Date.now(),
            nodes: nodes.map(n => ({
                id: n.id,
                type: n.type,
                position: n.position,
                data: n.data
            })),
            edges: edges.map(e => ({
                id: e.id,
                source: e.source,
                target: e.target
            })),
            deploy // Add the deploy flag
        };

        socket.emit('save-procedure', procedure);
    }, [socket, nodes, edges]);

    const selectedNode = selectedNodeId ? nodes.find(n => n.id === selectedNodeId) : null;

    return (
        <div className="flex h-full w-full overflow-hidden bg-slate-900 shadow-2xl">
            {/* Catalog Sidebar */}
            <ProcedureCatalog />

            {/* Main Canvas Area */}
            <div className="flex-1 relative" ref={reactFlowWrapper}>
                <ReactFlow
                    nodes={nodes.map(n => ({ ...n, position: n.position || { x: 0, y: 0 } }))}
                    edges={edges}
                    onNodesChange={onNodesChange}
                    onEdgesChange={onEdgesChange}
                    onConnect={onConnect}
                    onNodeClick={onNodeClick}
                    onPaneClick={onPaneClick}
                    onInit={setReactFlowInstance}
                    onDrop={onDrop}
                    onDragOver={onDragOver}
                    onConnectStart={onConnectStart}
                    onConnectEnd={onConnectEnd}
                    nodeTypes={nodeTypes}
                    fitView
                    className="bg-regatta-dark"
                    defaultEdgeOptions={{
                        type: 'smoothstep',
                        markerEnd: { type: MarkerType.ArrowClosed, color: '#06b6d4' }
                    }}
                    connectionLineStyle={{ stroke: '#06b6d4', strokeWidth: 3 }}
                    connectionLineType={ConnectionLineType.SmoothStep}
                >
                    <Background color="#333" gap={20} size={1} />
                    <Controls className="bg-white/10 border border-white/10 text-white fill-white" />
                </ReactFlow>

                {/* Internal Toolbar (Avoids Header) */}
                <div className="absolute top-6 left-1/2 -translate-x-1/2 z-10 flex gap-3 p-1.5 bg-black/60 backdrop-blur-md rounded-2xl border border-white/10 shadow-2xl">
                    <button
                        onClick={addNode}
                        className="flex items-center gap-2 pr-6 pl-4 py-3 bg-white/5 hover:bg-white/10 text-white rounded-xl text-[10px] font-black uppercase tracking-[0.2em] transition-all border border-white/5"
                    >
                        <Plus size={14} className="text-accent-blue" />
                        Add Step
                    </button>
                    <div className="w-[1px] h-10 bg-white/5" />
                    <button
                        onClick={() => saveProcedure(false)}
                        className="flex items-center gap-2 pr-6 pl-4 py-3 bg-accent-blue/10 hover:bg-accent-blue/20 text-accent-blue rounded-xl text-[10px] font-black uppercase tracking-[0.2em] transition-all border border-accent-blue/20 shadow-[0_0_20px_rgba(59,130,246,0.1)]"
                    >
                        <Save size={14} />
                        Save Procedure
                    </button>
                    <button
                        onClick={() => saveProcedure(true)}
                        className="flex items-center gap-2 pr-8 pl-6 py-3 bg-accent-blue text-white rounded-xl text-[10px] font-black uppercase tracking-[0.2em] transition-all shadow-[0_0_30px_rgba(59,130,246,0.3)] hover:scale-105"
                    >
                        <Play fill="currentColor" size={14} />
                        Save & Run
                    </button>
                </div>
            </div>

            {/* Properties Sidebar */}
            <PropertiesPanel
                selectedNode={selectedNode || null}
                onUpdate={onNodeUpdate}
                onClose={() => setSelectedNodeId(null)}
            />
        </div>
    );
}

export default function ProcedureDesigner({ currentProcedure }: { currentProcedure?: any }) {
    return (
        <ReactFlowProvider>
            <DesignerInner currentProcedure={currentProcedure} />
        </ReactFlowProvider>
    );
}
