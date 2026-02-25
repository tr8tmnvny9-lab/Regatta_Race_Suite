use crate::state::{Flight, FlightStatus, Pairing, Team};
use uuid::Uuid;

pub struct FlightEngine;

impl FlightEngine {
    /// Generates a fair rotation schedule for League racing based on Latin-Square / Cyclic Shift concepts.
    /// 
    /// Ensures that teams do not always sail the same boat, and that total races are distributed evenly.
    pub fn generate_rotation_schedule(
        teams: Vec<Team>,
        boats: u32,
        target_races: u32,
    ) -> (Vec<Flight>, Vec<Pairing>) {
        let mut flights = Vec::new();
        let mut pairings = Vec::new();
        
        let num_teams = teams.len();
        if num_teams < boats as usize || boats == 0 {
            // Cannot reliably generate flights if there are fewer teams than boats
            return (flights, pairings);
        }
        
        // Calculate the absolute number of flights required to fulfill target_races for everyone
        let total_flights = (num_teams as u32 * target_races + boats - 1) / boats;
        
        // Provide a stable vector of team indices to rotate through
        let team_indices: Vec<usize> = (0..num_teams).collect();
        
        for f in 0..total_flights {
            let flight_id = Uuid::new_v4().to_string();
            let flight = Flight {
                id: flight_id.clone(),
                flight_number: f + 1,
                group_label: format!("Flight {}", f + 1),
                status: FlightStatus::Scheduled,
            };
            flights.push(flight);
            
            // Pick `boats` consecutive teams cyclically
            for b_idx in 0..(boats as usize) {
                let team_idx = team_indices[(f as usize * boats as usize + b_idx) % num_teams];
                let team = &teams[team_idx];
                
                // Determine boat assignment
                // We use `+ f` in the modulo math so that when a team is scheduled in a future flight,
                // their assigned boat shifts cyclically, satisfying the "fair rotation" requirement.
                let boat_number = ((team_idx + f as usize) % boats as usize) + 1;
                
                pairings.push(Pairing {
                    id: Uuid::new_v4().to_string(),
                    flight_id: flight_id.clone(),
                    team_id: team.id.clone(),
                    boat_id: boat_number.to_string(), // Effectively mapping to Boat "1", "2", "3"
                });
            }
        }
        
        (flights, pairings)
    }
}
