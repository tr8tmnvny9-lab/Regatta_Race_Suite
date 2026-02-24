use std::time::Instant;
use tracing::info;

use crate::state::{ProcedureGraph, ProcedureNode, SequenceInfo, SequenceUpdate};

/// Tick-based procedure sequencer — port of ProcedureEngine.ts
pub struct ProcedureEngine {
    graph: Option<ProcedureGraph>,
    current_node_id: Option<String>,
    node_started_at: Option<Instant>,
    sequence_started_at: Option<Instant>,
}

impl ProcedureEngine {
    pub fn new() -> Self {
        Self {
            graph: None,
            current_node_id: None,
            node_started_at: None,
            sequence_started_at: None,
        }
    }

    pub fn load_procedure(&mut self, graph: ProcedureGraph) {
        info!("Loading procedure: {} ({} nodes, {} edges)", graph.id, graph.nodes.len(), graph.edges.len());
        self.graph = Some(graph);
        self.current_node_id = None;
    }

    pub fn get_graph(&self) -> Option<&ProcedureGraph> {
        self.graph.as_ref()
    }

    /// Jump to a specific node by ID (trigger-node event).
    pub fn jump_to_node(&mut self, node_id: &str) -> Option<SequenceUpdate> {
        let graph = self.graph.as_ref()?;
        if graph.nodes.iter().any(|n| n.id == node_id) {
            self.current_node_id = Some(node_id.to_string());
            self.node_started_at = Some(Instant::now());
            info!("Jumped to node: {node_id}");
            self.build_update()
        } else {
            None
        }
    }

    /// Start the procedure from the first node.
    pub fn start(&mut self) -> Option<SequenceUpdate> {
        let graph = self.graph.as_ref()?;

        // Find node with id "1" or fall back to first node
        let start_node = graph.nodes.iter()
            .find(|n| n.id == "1")
            .or_else(|| graph.nodes.first())?;

        let node_id = start_node.id.clone();
        info!("Starting procedure at node: {node_id}");

        self.current_node_id = Some(node_id);
        self.node_started_at = Some(Instant::now());
        self.sequence_started_at = Some(Instant::now());

        self.build_update()
    }

    pub fn stop(&mut self) {
        self.current_node_id = None;
        self.node_started_at = None;
    }

    pub fn is_running(&self) -> bool {
        self.current_node_id.is_some()
    }

    /// Called at 5Hz. Returns Some(update) whenever state needs to be broadcast.
    pub fn tick(&mut self) -> TickResult {
        let graph = match &self.graph {
            Some(g) => g,
            None => return TickResult::Idle,
        };
        let current_id = match &self.current_node_id {
            Some(id) => id.clone(),
            None => return TickResult::Idle,
        };
        let started_at = match self.node_started_at {
            Some(t) => t,
            None => return TickResult::Idle,
        };

        let current_node = match graph.nodes.iter().find(|n| n.id == current_id) {
            Some(n) => n,
            None => return TickResult::Idle,
        };

        let elapsed = started_at.elapsed().as_secs_f64();
        let duration = current_node.data.duration;

        if duration > 0.0 && elapsed >= duration {
            // Transition to next node
            self.transition_next()
        } else {
            // Still in current node — emit time update
            match self.build_update() {
                Some(update) => TickResult::Update(update),
                None => TickResult::Idle,
            }
        }
    }

    fn transition_next(&mut self) -> TickResult {
        let current_id = match &self.current_node_id {
            Some(id) => id.clone(),
            None => return TickResult::Idle,
        };

        let next_id = self.graph.as_ref()
            .and_then(|g| g.edges.iter().find(|e| e.source == current_id))
            .map(|e| e.target.clone());

        match next_id {
            Some(id) => {
                info!("Procedure: transitioning to node {id}");
                self.current_node_id = Some(id);
                self.node_started_at = Some(Instant::now());
                match self.build_update() {
                    Some(upd) => TickResult::Update(upd),
                    None => TickResult::Idle,
                }
            }
            None => {
                // End of graph — race starts
                info!("Procedure: sequence complete, transitioning to RACING");
                self.current_node_id = None;
                self.node_started_at = None;
                TickResult::SequenceComplete
            }
        }
    }

    fn build_update(&self) -> Option<SequenceUpdate> {
        let graph = self.graph.as_ref()?;
        let current_id = self.current_node_id.as_ref()?;
        let started_at = self.node_started_at?;

        let current_node = graph.nodes.iter().find(|n| &n.id == current_id)?;

        let elapsed = started_at.elapsed().as_secs_f64();
        let duration = current_node.data.duration;
        let node_remaining = if duration > 0.0 {
            (duration - elapsed).max(0.0).ceil()
        } else {
            0.0
        };

        let total_remaining = self.calculate_total_remaining(current_node, elapsed);

        Some(SequenceUpdate {
            status: "PRE_START".to_string(),
            current_sequence: SequenceInfo {
                event: current_node.data.label.clone(),
                flags: current_node.data.flags.clone(),
            },
            sequence_time_remaining: total_remaining,
            node_time_remaining: node_remaining,
            current_node_id: current_id.clone(),
        })
    }

    fn calculate_total_remaining(&self, current_node: &ProcedureNode, elapsed_in_node: f64) -> f64 {
        let graph = match &self.graph {
            Some(g) => g,
            None => return 0.0,
        };

        let mut total = (current_node.data.duration - elapsed_in_node).max(0.0);
        let mut next_id = self.get_next_node_id(&current_node.id);
        let mut visited = std::collections::HashSet::new();
        visited.insert(current_node.id.clone());

        while let Some(id) = next_id {
            if visited.contains(&id) {
                break; // loop guard
            }
            if let Some(node) = graph.nodes.iter().find(|n| n.id == id) {
                total += node.data.duration;
                visited.insert(id.clone());
                next_id = self.get_next_node_id(&id);
            } else {
                break;
            }
        }

        total.max(0.0).ceil()
    }

    fn get_next_node_id(&self, node_id: &str) -> Option<String> {
        self.graph.as_ref()
            .and_then(|g| g.edges.iter().find(|e| e.source == node_id))
            .map(|e| e.target.clone())
    }
}

pub enum TickResult {
    Idle,
    Update(SequenceUpdate),
    SequenceComplete,
}
