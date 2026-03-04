# Regatta Pro: Master Feature Catalog

Use this document to list every granular feature and setting for the Regatta Pro suite. I will refer to this list during implementation to ensure 100% parity and precision.

## 🗺️ Course Builder
- [ ] **Layout**
Course builder tool on the left of the screen pops out of the Regatta pro tools selector and widens it.
At the top has the different placeable objects (all the buoy related marks not the boats as they show on the basis of tracker), shows small figures of the tye hence gate, start line, finnish line, single mark
Under the mark selector tool comes all the placed marks you can delete them using that list or access their individual settings 
The standard map is in the back of the whole screen you start the course building by clicking a define course boundary this can either be done manually or taken from a place specific pre made library. this area is drwan if manually made by clicking on the areas preferd outline places and it connects the area from first to last point to encircle the intended course area. Can be deleted if you want to re do it. 
After placing the marks it will ask if you want to place restriction zones withing the race course area. These wil be with the given yellow dotted lines connected by light yellow string 
After that you click finnish course boundary setup and it will ask you to place the marks or select pre made coursese layouts, by draging individual marks or the pictures of entire courses to the given course area. Allow courses to be saved to the system and or to the library of pre made ones and to be able to give names to the pre made courses. 
Each marks settigns can be changed either by clicking the individual mark or from the course builder toolbar mark list. 
In that tool list you can also find measure that allows you to measure between two points and to either leave the measurement visible or to toggle it in to a one time measurement mode also. the masure tool should have the ability to measure from the angle of the measurerer hence the first point in the measurement to the second point the compas angle of that given mark.
- [ ] **Standard Mark Settings**
    - [ ] Change Color (Red, Green, Yellow, Orange, Blue)
    - [ ] Change Type (Cylindrical, Spherical, Spar with flag, MarkSetBot (two pontoons with a low taper cylinder ontop))
    - [ ] Rounding Direction (Port / Starboard)
    - [ ] Labeling (Custom name/number)
    - [ ] ID, non changeable for backend use 
    - [ ] Toggle Laylines per mark
    - [ ] leiline direction upwinf or downwind / changes leilines direction 180 degrees 
- [ ] **Course objects**
Start line and Finnish line two separate: consists of two marks 80m as standard apart and perpendicular to the wind direction not (not fixed as marks may move and proportions change)(as stadard should be set with Pole with red flags on both sides can be toggled that right side is a boat with a red flag to singify commitie boat in the buoy settings for the start and finnish line)
Single mark: one buoy and has all the same settings
Gate: Two marks with buoys as starting apearance and yellow color, all standard mark settings apply
Sailboat: top down view: has ID, can get colour defined fro mthe back end is movable has a froward direction will get states (reaching, croswind, downwind) to signify on what section it is curently on Sail is on the downwind side of the boat compared to the wind in each state, is in the location of a tracker defined as a sailboat in the fleet managemnt 
Jurry boat: top down view of a standard rib boat : has ID, can get colour defined to match the back end, is in the loaction of a tracker defined as a jurry in th efleet managemnt 
Help, Media, or Safety boat: top down view of a standard RIB boat: has ID, can get colour defined to match the back end, is in the loaction of a tracker defined as a help, media, or safety boat in the fleet managemnt
Boundary linne: is lught blue colour straight lines that enclose and area and cannot be placed on ground can only be on water. 
Boundary line withing boundary area: Yellow chaned dots marking an area within the boundary area that is a no go zone cna be changed in colour to the standard colours has a line going in between the yellow dots representign floating mini buoys 
- [ ] **Advanced Specifications**
Each Buoy marks real location is at the foot of each mark rather than the center of the symbol 
All non tracker defined objects are drag and droppable but otherwise static uless changed from the backend their location is saved in the backend and will be loaded in the same place when the app is opened again
A line dotted line is connecting the both ends of start line, both ends of finish line, and both ends of gates to define the gap allow in their individual settings to define the distance between the two points
Ones the race course is designed The map whitch has the race course and all the trackable objects witch is the main screen should center arround the drawn race course.
## ⏱️ Start Procedure
- Purpose 
    Funktion as the controll panel for the start of the race. It should in code terms slave the presets set in the  procedure architec as there are many different start procedure formats a sailing competition can use. and thus the available controlls should be shown accordimgly
    IT shluld be clear with good sight of the map and as big as possible buttons for each of the funktions defined by the current state of the procedure architect. 
-Visuals
    You should have three separate views for this that are in real time synced to the state engine running in the background witch should slve the pre sets of the procedure architecht. The three sections should be as follows. 
        - left side column wide: Should have all the main atributes souch as a acurate clock and below it a big regatta timer under that there should be a horizontal timeline of the "primary start procedure" that shows each part of the primary start preocedure higlights whitch one youre on and waht flags should be up or taken down at each given step and what the regatta time will be at that point and a rolling clock untill the given procedural step is to come. 
        - middle section: Should have the map with the race course and all the trackable objects witch is the main screen. The middle section shuould have a toolbar in the top that allows the user to choose how the center map moves or is locked in place or follows the center of the fleet defined by an invicible polygon that connects the boats that are on the endge so to say. 
        - lower section horizontal: should have big buttons for each of the funktions defined by the current state of the procedure architect. It is important thatt the buttons are made with fancy aplle liquid glass buttons that look like they are 3d and are so to say see through although there isnt anything really behind them, assure they move like buttons when pressed in. THe lover section shjould be split into three sections side by side and take a slim but very wide section of the lover part of the screen the center should have a confirmation button in the same style that needs to be held down simultaneously with whatever oter button is pressed on the lover section this is for touch screen users. for computer users it should be a confirmation also but have a text that says confrim and under it whatever button that was pressed before so you can confirm what youre about to do. THe left third of the lover section is for all the start related buttons like Start the procedure, AP up N ( only available if race is on ) and when AP or N is up the smae button is for taking them down that starts 1 min to class flag etc. according to the start procedure architect. 
        - The right vertical coulmn is for either a secondary start procedure or for rules book from World sailing or to access notice of race document or The race orders. can also be changed to a chat room for the jurry logs and or to get mini views out of the onboard cameras streamed form the tracker app 
    
## ⏱️ Procedure Architect
- **Overview**
    The Procedure Architect provides a visual node/step editor for designing the sequence of events governing a race start. Each step executes top-to-bottom by a state engine, configuring durations, flags, sounds, and manual pauses.
- [ ] **Step Configurations**
    - [ ] **Label**: Descriptive name for the step (e.g., "Warning Signal", "Preparatory").
    - [ ] **Duration**: Configurable countdown time in seconds.
    - [ ] **Manual Trigger**: Toggle to pause the procedure until a user explicitly clicks to advance. When enabled, requires providing a custom **Action Label** (e.g., "START WARNING SEQUENCE", "FINISH RACE").
    - [ ] **Race Status**: Override for the race state. Options: `Auto-detect`, `IDLE`, `WARNING`, `PREPARATORY`, `ONE_MINUTE`, `RACING`, `FINISHED`.
    - [ ] **Flags**: Multi-select of valid RRS flags raised at the start of the step. Available flags: `CLASS`, `P`, `I`, `Z`, `U`, `BLACK`, `AP`, `N`, `X`, `FIRST_SUB`, `S`, `L`, `ORANGE`.
    - [ ] **Sounds**:
        - **Sound at Start**: Audio signal fired when the step begins (`No Sound`, `1 Short`, `1 Long`, `2 Short`, `3 Short`).
        - **Sound on Flag Remove**: Audio signal fired when flags from this step are lowered.
    - [ ] **Hardware Sync (Smart Horns/Lights)**: Toggle to map the step's digital sound/flag configurations to connected physical RC boat hardware (e.g., compressed-air horns, LED arrays).
    - [ ] **Auto VHF Broadcast**: Toggle and accompanying text field to define a synthesized text-to-speech announcement broadcasted over the RC radio channel when the step begins (e.g., "Warning signal in 1 minute").
- [ ] **Procedure Templates (Presets)**
    - [ ] **Standard 5-Min (RRS 26)**:
        - Step 1: Warning Signal (60s, `CLASS` flag, 1 Short sound, `WARNING` status)
        - Step 2: Preparatory Signal (180s, `CLASS` + `P` flags, 1 Short sound, `PREPARATORY` status, 1 Long sound on remove)
        - Step 3: One-Minute (60s, `CLASS` flag, 1 Long sound, `ONE_MINUTE` status)
        - Step 4: Start (0s, no flags, 1 Short sound, `RACING` status)
        - Step 5: Racing (0s, manual step: "FINISH RACE — End racing", `RACING` status)
    - [ ] **Short Course 3-Min**:
        - Similar to 5-Min, but the Preparatory Signal duration is 60s instead of 180s.
    - [ ] **League UF (Umpired) / Finnish Sailing League Format**:
        - Step 1: Pre-Start Alert (0s, `ORANGE` flag, 1 Long sound, `IDLE` status, Manual trigger: "START WARNING SEQUENCE")
        - Step 2: Warning Signal (60s, `CLASS` flag, 1 Short sound, `WARNING` status)
        - Step 3: Preparatory Signal (180s, `CLASS` + `P` flags, 1 Short sound, `PREPARATORY` status, 1 Long sound on remove)
        - Step 4: One-Minute (60s, `CLASS` flag, 1 Long sound, `ONE_MINUTE` status)
        - Step 5: Start (0s, no flags, 1 Short sound, `RACING` status)
        - Step 6: Racing (Umpired) (0s, manual step: "FINISH RACE — End racing", `RACING` status)
- [ ] **Playback Modes & Settings**
    - [ ] **Auto Restart (Rolling Starts)**: A toggle ("Rolling On/Off") that continually restarts the procedure loop after a start for running back-to-back fleets.
- [ ] **Global RRS Interruptions & Mid-Race Actions (Overrides)**
    - The Procedure Architect must support injecting or overriding the linear flow with global RRS actions that can happen at any time (pre-start or mid-race).
    - [ ] **Postponement (AP)**:
        - **Action**: Raises AP flag, fires 2 sounds, pauses the current countdown, and changes race status to `POSTPONEMENT`.
        - **Resumption**: Lower AP flag, fire 1 sound. Exactly 1 minute later, the Warning Signal step is triggered automatically.
    - [ ] **Abandonment (N)**:
        - **Pre-Start / Mid-Race**: Raises N flag (or N over H/A), fires 3 sounds. 
        - **Resumption**: Lower N flag, fire 1 sound. Exactly 1 minute later, the Warning Signal step is triggered automatically.
    - [ ] **General Recall (1st Substitute)**:
        - **Action**: Triggered immediately after a Start if multiple unidentified boats are OCS (On Course Side). Raises 1st Substitute flag, fires 2 sounds.
        - **Resumption**: Lower 1st Substitute, fire 1 sound. Exactly 1 minute later, the Warning Signal step is triggered automatically.
    - [ ] **Individual Recall (X Flag)**:
        - **Action**: Triggered immediately after a Start if specific identified boats are OCS. Raises X flag, fires 1 sound.
        - **Removal**: Flag is kept raised until all OCS boats have restarted correctly, or for a maximum of 4 minutes (or 1 minute before the next start).
    - [ ] **Mid-Race Interventions (Course Changes / Shortening)**:
        - **Shorten Course (S Flag)**: Raises S flag, fires 2 sounds as the leading boat approaches the new finish line.
        - **Change of Course (C Flag)**: Raises C flag with repetitive sounds at a rounding mark to indicate the next leg has been changed.
    - [ ] **Penalty Flag Overrides (U, Black, Z)**:
        - The Procedure Architect must allow the Principal Race Officer (PRO) to dynamically swap the Preparatory flag (P) to a penalty flag (I, Z, U, or Black) for restarts following a General Recall or Abandonment.
- [ ] **Mac App Navigation**
    - The Procedure Architect must be accessible from the main tool selector menu in the Regatta Pro Mac application.
    - Its icon should represent a node connected to another (e.g., `point.topleft.down.curvedto.point.bottomright.up` or a similarly styled SF Symbol).
- [ ] **Visual Layout & UI (Liquid Glass Aesthetic)**
    - The layout will adopt a transparent "Liquid Glass" styling floating over the background tactical map.
    - **Main Area (Step Pipeline)**: Occupying the left 2/3 of the screen.
        - **Header**: Includes controls to 'Add Step', 'Deploy & Start', and toggle 'Auto Restart'.
        - **Step List**: A vertically scrollable, drag-and-drop sortable list of procedure steps.
        - **Step Cards (Collapsed)**: Each row displays the step number, label, duration, required flags, and required sounds. Features an expand/collapse toggle and a delete mechanism.
        - **Step Cards (Expanded)**: Placed inside a smooth animated accordion, revealing granular controls: textual duration entry, manual trigger toggles, race status overrides, action label typing, a multi-select grid for flags, sound dropdowns, and toggles/inputs for Hardware Sync and Auto VHF Broadcasts.
    - **Right Sidebar (Presets & Summary)**: Occupying the right 1/3 of the screen.
        - **Templates Vault**: One-click quick load buttons for the `Standard 5-Min`, `Short Course 3-Min`, and `League UF (Umpired)` procedures.
        - **Live Summary**: A dynamic glass panel tallying the total duration, manual steps count, unique flag changes, and sound events currently scheduled in the architect pipeline.
        - **RRS Reference Guide**: A small, quick-reference key for common Race Rules of Sailing (RRS) signals to assist the architect.
## ⛵ Fleet Management

## 📊 Overview & Dashboard

## ⚖️ Jury & Media
