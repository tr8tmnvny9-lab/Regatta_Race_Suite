
interface ProcedureNode {
    id: string;
    type: string; // 'state'
    data: {
        label: string;
        flags?: string[];
        duration?: number;
        sound?: string;
    };
}

interface ProcedureEdge {
    id: string;
    source: string;
    target: string;
    animated?: boolean;
}

export interface ProcedureGraph {
    id: string;
    nodes: ProcedureNode[];
    edges: ProcedureEdge[];
}

export class ProcedureEngine {
    private graph: ProcedureGraph | null = null;
    private currentNodeId: string | null = null;
    private nodeStartTime: number = 0;
    private sequenceStartTime: number = 0;

    // Callback for state updates
    private onStateUpdate: (state: any) => void;

    constructor(onStateUpdate: (state: any) => void) {
        this.onStateUpdate = onStateUpdate;
    }

    public loadProcedure(graph: ProcedureGraph) {
        this.graph = graph;
    }

    public getGraph(): ProcedureGraph | null {
        return this.graph;
    }

    public jumpToNode(nodeId: string) {
        if (!this.graph) return;
        const node = this.graph.nodes.find(n => n.id === nodeId);
        if (node) {
            this.currentNodeId = nodeId;
            this.nodeStartTime = Date.now();
            this.emitUpdate();
        }
    }

    public start() {
        if (!this.graph) return;

        // Find start node (node with no incoming edges? or specific type?)
        // For now, assume first node in array or look for 'start' type if we had one.
        // Let's assume the node with id '1' is start for this MVP, or find one without incoming edges.

        const startNode = this.graph.nodes.find(n => n.id === '1') || this.graph.nodes[0];
        if (!startNode) return;

        this.currentNodeId = startNode.id;
        this.nodeStartTime = Date.now();
        this.sequenceStartTime = Date.now();

        this.emitUpdate();
    }

    public stop() {
        this.currentNodeId = null;
    }

    public tick() {
        if (!this.graph || !this.currentNodeId) return;

        const currentNode = this.graph.nodes.find(n => n.id === this.currentNodeId);
        if (!currentNode) return;

        const elapsed = (Date.now() - this.nodeStartTime) / 1000;
        const duration = currentNode.data.duration || 0;

        if (elapsed >= duration) {
            this.transitionToNextNode(currentNode.id);
        } else {
            // Just update time remaining for current node if needed
            // But usually we sequence time. 
            // The frontend wants "Total Time Remaining" for the sequence.
            // This is hard to calculate with a graph. 
            // For MVP, we send "Time Remaining in Current Step".
            this.emitUpdate();
        }
    }

    private transitionToNextNode(currentId: string) {
        if (!this.graph) return;

        const edge = this.graph.edges.find(e => e.source === currentId);

        if (edge) {
            this.currentNodeId = edge.target;
            this.nodeStartTime = Date.now();
            this.emitUpdate();
        } else {
            // End of sequence
            this.onStateUpdate({
                status: 'RACING', // Or FINISHED_SEQUENCE
                currentSequence: { event: 'STARTED', flags: [] },
                sequenceTimeRemaining: 0
            });
            this.currentNodeId = null;
        }
    }

    private emitUpdate() {
        if (!this.graph || !this.currentNodeId) return;

        const currentNode = this.graph.nodes.find(n => n.id === this.currentNodeId);
        if (!currentNode) return;

        const elapsed = (Date.now() - this.nodeStartTime) / 1000;
        const duration = currentNode.data.duration || 0;
        const remaining = Math.max(0, Math.ceil(duration - elapsed));

        // Calculate total time remaining by traversing the path
        const totalRemaining = this.calculateTotalTimeRemaining(currentNode, elapsed);

        this.onStateUpdate({
            status: 'PRE_START',
            currentSequence: {
                event: currentNode.data.label,
                flags: currentNode.data.flags || []
            },
            sequenceTimeRemaining: totalRemaining,
            nodeTimeRemaining: remaining, // Also send node specific time
            currentNodeId: this.currentNodeId
        });
    }

    private calculateTotalTimeRemaining(currentNode: ProcedureNode, elapsedInNode: number): number {
        if (!this.graph) return 0;

        let total = (currentNode.data.duration || 0) - elapsedInNode;
        let nextId = this.getNextNodeId(currentNode.id);

        // Safety: limit recursion depth or check for loops
        const visited = new Set<string>();
        visited.add(currentNode.id);

        while (nextId && !visited.has(nextId)) {
            const nextNode = this.graph.nodes.find(n => n.id === nextId);
            if (!nextNode) break;

            total += (nextNode.data.duration || 0);
            visited.add(nextId);
            nextId = this.getNextNodeId(nextId);
        }

        return Math.max(0, Math.ceil(total));
    }

    private getNextNodeId(nodeId: string): string | undefined {
        return this.graph?.edges.find(e => e.source === nodeId)?.target;
    }
}
