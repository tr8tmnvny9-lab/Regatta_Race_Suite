To clarify the Manual Pairings Override architecture:

Currently, the iPads (Trackers) are manually configured in their Settings to be named after a boat (e.g., `boatId = "1"`).

When you say:
> "top horizontal axis you have tracker, left column Boat ID. assign boats trackers."

Are you suggesting that we should:
1. Hardcode the iPads to unique IDs (like `Tracker-A`, `Tracker-B`), and RegattaPro is responsible for mapping an incoming `Tracker-A` to `Boat 1` (and applying the team assigned to Boat 1)?
2. OR, do you just want to reassign which **Team** is on which **Boat** during a specific Flight/Race, and leave the Trackers permanently strapped to their respective physical boats?

If it's #1, I will need to introduce a new `trackerId` field to your Pairing scheme so the Engine can dynamically rewrite telemetry from `Tracker-B` to `Boat 1`. Please let me know!
