use std::time::Instant;
use tracing::info;

use crate::state::{ProcedureGraph, ProcedureNode, RaceStatus, SequenceInfo, SequenceUpdate, SoundSignal};

/// Tick-based procedure sequencer — RRS-compliant state machine
pub struct ProcedureEngine {
    pub graph: Option<ProcedureGraph>,
    pub current_node_id: Option<String>,
    pub node_started_at: Option<Instant>,
    pub sequence_started_at: Option<Instant>,
    pub is_post_trigger: bool,
    pub post_trigger_started_at: Option<Instant>,
}

impl ProcedureEngine {
    pub fn update_node_duration(&mut self, node_id: &str, new_duration: f64) {
        if let Some(graph) = &mut self.graph {
            if let Some(node) = graph.nodes.iter_mut().find(|n| n.id == node_id) {
                node.data.duration = new_duration;
            }
        }
    }
    pub fn new() -> Self {
        Self {
            graph: None,
            current_node_id: None,
            node_started_at: None,
            sequence_started_at: None,
            is_post_trigger: false,
            post_trigger_started_at: None,
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
            self.sequence_started_at = Some(Instant::now());
            self.is_post_trigger = false;
            self.post_trigger_started_at = None;
            info!("Jumped to node: {node_id}");
            self.build_update()
        } else {
            None
        }
    }

    /// Resume the sequence manually (user trigger button pressed)
    pub fn resume_sequence(&mut self) -> Option<SequenceUpdate> {
        let current_id = self.current_node_id.clone()?;
        let graph = self.graph.as_ref()?;
        let current_node = graph.nodes.iter().find(|n| n.id == current_id)?;

        // If it has post-trigger logic and we are not in it yet, transition to it
        if !self.is_post_trigger && current_node.data.post_trigger_duration > 0.0 {
            self.is_post_trigger = true;
            self.post_trigger_started_at = Some(Instant::now());
            self.build_update()
        } else {
            // Otherwise, jump to the next node
            match self.transition_next() {
                TickResult::Update(u) => Some(u),
                _ => None,
            }
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
        self.is_post_trigger = false;
        self.post_trigger_started_at = None;

        self.build_update()
    }

    /// Stop the engine (used by postpone, abandon, general recall)
    pub fn stop(&mut self) {
        self.current_node_id = None;
        self.node_started_at = None;
        self.is_post_trigger = false;
        self.post_trigger_started_at = None;
    }

    pub fn is_running(&self) -> bool {
        self.current_node_id.is_some()
    }

    /// Determine which RaceStatus maps to the current node label
    pub fn current_race_status(&self) -> RaceStatus {
        let graph = match &self.graph {
            Some(g) => g,
            None => return RaceStatus::Idle,
        };
        let current_id = match &self.current_node_id {
            Some(id) => id,
            None => return RaceStatus::Idle,
        };
        let node = match graph.nodes.iter().find(|n| &n.id == current_id) {
            Some(n) => n,
            None => return RaceStatus::Idle,
        };

        // Check for explicit raceStatus override on the node
        if let Some(ref status_str) = node.data.race_status {
            return match status_str.as_str() {
                "IDLE" => RaceStatus::Idle,
                "WARNING" => RaceStatus::Warning,
                "PREPARATORY" => RaceStatus::Preparatory,
                "ONE_MINUTE" => RaceStatus::OneMinute,
                "RACING" => RaceStatus::Racing,
                "FINISHED" => RaceStatus::Finished,
                "POSTPONED" => RaceStatus::Postponed,
                "INDIVIDUAL_RECALL" => RaceStatus::IndividualRecall,
                "GENERAL_RECALL" => RaceStatus::GeneralRecall,
                "ABANDONED" => RaceStatus::Abandoned,
                _ => RaceStatus::Idle,
            };
        }

        // Auto-detect from label if no override
        let label_lower = node.data.label.to_lowercase();
        if label_lower.contains("warning") {
            RaceStatus::Warning
        } else if label_lower.contains("preparatory") || label_lower.contains("prep") {
            RaceStatus::Preparatory
        } else if label_lower.contains("one-minute") || label_lower.contains("one minute") || label_lower.contains("1-minute") {
            RaceStatus::OneMinute
        } else if label_lower.contains("start") {
            // Starting signal node — still part of the pre-start sequence
            RaceStatus::OneMinute
        } else if label_lower.contains("racing") || label_lower.contains("race") {
            RaceStatus::Racing
        } else if label_lower.contains("idle") {
            RaceStatus::Idle
        } else {
            // Default: if engine is running, it's in the pre-start zone
            RaceStatus::Warning
        }
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

        if self.is_post_trigger {
            let post_started_at = match self.post_trigger_started_at {
                Some(t) => t,
                None => return TickResult::Idle,
            };
            let post_elapsed = post_started_at.elapsed().as_secs_f64();
            let post_dur = current_node.data.post_trigger_duration;

            if post_elapsed >= post_dur {
                self.transition_next()
            } else {
                match self.build_update() {
                    Some(update) => TickResult::Update(update),
                    None => TickResult::Idle,
                }
            }
        } else {
            let is_waiting = current_node.data.wait_for_user_trigger && (duration == 0.0 || elapsed >= duration);

            if duration > 0.0 && elapsed >= duration && !is_waiting {
                // Transition to next mode - might be post trigger
                if current_node.data.post_trigger_duration > 0.0 {
                    self.is_post_trigger = true;
                    self.post_trigger_started_at = Some(Instant::now());
                    match self.build_update() {
                        Some(update) => TickResult::Update(update),
                        None => TickResult::Idle,
                    }
                } else {
                    self.transition_next()
                }
            } else if duration == 0.0 && !is_waiting {
                self.transition_next()
            } else {
                // Still in current node — emit time update
                match self.build_update() {
                    Some(update) => TickResult::Update(update),
                    None => TickResult::Idle,
                }
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
                self.is_post_trigger = false;
                self.post_trigger_started_at = None;
                match self.build_update() {
                    Some(upd) => TickResult::Update(upd),
                    None => TickResult::Idle,
                }
            }
            None => {
                // End of graph — check if auto_restart is true for rolling sequences
                let should_loop = self.graph.as_ref().map(|g| g.auto_restart).unwrap_or(false);
                if should_loop {
                    // Start over at node 0 (Idle) or node 1 depending on graph layout, but let's just go to nodes.first()
                    if let Some(first_node) = self.graph.as_ref().and_then(|g| g.nodes.first()) {
                        info!("Procedure: auto-restarting sequence to node {}", first_node.id);
                        self.current_node_id = Some(first_node.id.clone());
                        self.node_started_at = Some(Instant::now());
                        self.is_post_trigger = false;
                        self.post_trigger_started_at = None;
                        return match self.build_update() {
                            Some(upd) => TickResult::Update(upd),
                            None => TickResult::Idle,
                        };
                    }
                }

                // End of graph — sequence complete
                info!("Procedure: sequence complete");
                self.current_node_id = None;
                self.node_started_at = None;
                self.is_post_trigger = false;
                self.post_trigger_started_at = None;
                TickResult::SequenceComplete
            }
        }
    }

    pub fn build_update(&self) -> Option<SequenceUpdate> {
        let graph = self.graph.as_ref()?;
        let current_id = self.current_node_id.as_ref()?;
        let started_at = self.node_started_at?;

        let current_node = graph.nodes.iter().find(|n| &n.id == current_id)?;

        let elapsed = started_at.elapsed().as_secs_f64();
        let duration = current_node.data.duration;

        let is_waiting = !self.is_post_trigger && current_node.data.wait_for_user_trigger && (duration == 0.0 || elapsed >= duration);
        
        let node_remaining = if self.is_post_trigger {
            let p_elapsed = self.post_trigger_started_at?.elapsed().as_secs_f64();
            let p_dur = current_node.data.post_trigger_duration;
            (p_dur - p_elapsed).max(0.0).ceil()
        } else {
            if duration > 0.0 {
                (duration - elapsed).max(0.0).ceil()
            } else {
                0.0
            }
        };

        let total_remaining = self.calculate_total_remaining(current_node, elapsed);
        
        // Use post trigger flags if we are in that phase and they exist, otherwise use standard flags
        let active_flags = if self.is_post_trigger && !current_node.data.post_trigger_flags.is_empty() {
            current_node.data.post_trigger_flags.clone()
        } else {
            current_node.data.flags.clone()
        };

        // Determine the correct RaceStatus for this node
        let status = self.current_race_status();
        let status_str = match status {
            RaceStatus::Idle => "IDLE",
            RaceStatus::Warning => "WARNING",
            RaceStatus::Preparatory => "PREPARATORY",
            RaceStatus::OneMinute => "ONE_MINUTE",
            RaceStatus::Racing => "RACING",
            RaceStatus::Finished => "FINISHED",
            RaceStatus::Postponed => "POSTPONED",
            RaceStatus::IndividualRecall => "INDIVIDUAL_RECALL",
            RaceStatus::GeneralRecall => "GENERAL_RECALL",
            RaceStatus::Abandoned => "ABANDONED",
        };

        // Only emit sound on the first tick of a node (< 0.3s elapsed)
        let sound = if elapsed < 0.3 && !self.is_post_trigger {
            current_node.data.sound.clone()
        } else {
            SoundSignal::None
        };

        Some(SequenceUpdate {
            status: status_str.to_string(),
            current_sequence: SequenceInfo {
                event: current_node.data.label.clone(),
                flags: active_flags,
            },
            sequence_time_remaining: total_remaining,
            node_time_remaining: node_remaining,
            current_node_id: current_id.clone(),
            waiting_for_trigger: is_waiting,
            action_label: current_node.data.action_label.clone(),
            is_post_trigger: self.is_post_trigger,
            sound,
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
