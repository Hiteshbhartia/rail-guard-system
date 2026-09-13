# Rail Guard System

You are an expert Digital Logic Design / ADLD engineer and Verilog developer.

Build a COMPLETE, WORKING ADLD project from scratch in the current workspace.

PROJECT TITLE:
"Smart Railway Level-Crossing Controller with Obstacle Detection and Emergency Override"

IMPORTANT:
This project is inspired by the structure and technical level of a typical FSM-based traffic controller project, but it MUST NOT be a traffic-light controller and MUST NOT simply rename traffic-light states or variables.

The actual system must be a railway level-crossing controller with a genuinely different FSM, behavior, simulation, and visualization.

==================================================

1. TECHNOLOGY STACK
   ==================================================

Use:

* Verilog HDL
* Icarus Verilog
* GTKWave-compatible VCD waveform
* Verilog testbench
* Bash scripts where useful
* Python 3
* Flask for the web application
* HTML
* CSS
* JavaScript

Do NOT require proprietary software.

The project must work on a normal Linux environment with:

iverilog
vvp
gtkwave
python3
flask

If Flask is not installed, create a requirements.txt.

==================================================
2. PROJECT STRUCTURE
====================

Create this structure:

smart_railway_crossing/
│
├── rtl/
│   └── railway_crossing_controller.v
│
├── tb/
│   └── tb_railway_crossing_controller.v
│
├── sim/
│   └── railway_crossing.vcd
│
├── web/
│   ├── app.py
│   ├── templates/
│   │   └── index.html
│   └── static/
│       ├── style.css
│       └── script.js
│
├── scripts/
│   ├── run_sim.sh
│   └── run_web.sh
│
├── requirements.txt
└── README.md

You may add additional files if genuinely useful, but keep the project understandable for an ADLD student.

==================================================
3. MAIN SYSTEM
==============

The system is an automatic railway level crossing.

When a train approaches:

1. Detect the train.
2. Turn railway signal RED.
3. Turn warning light ON.
4. Activate buzzer.
5. Wait for a configurable warning period.
6. Close the railway barrier.
7. Keep the barrier closed while the train is passing.
8. Detect train departure.
9. Open the barrier.
10. Return safely to IDLE.

The controller must be implemented using a finite state machine.

==================================================
4. INPUTS
=========

Use these inputs:

clk
rst_n
train_approach
train_from_left
train_from_right
train_departed
obstacle_detected
emergency_override
manual_reset

All signals should be clearly documented.

==================================================
5. OUTPUTS
==========

Use:

warning_light
buzzer
rail_signal_red
barrier_up
barrier_down
barrier_moving
emergency_indicator

Also expose the current FSM state and timer in a way that the testbench and web simulator can display them.

==================================================
6. FSM
======

Implement at least these 8 states:

S_IDLE
S_WARNING
S_CLOSING
S_CLOSED
S_TRAIN_PASSING
S_OPENING
S_SAFETY_HOLD
S_EMERGENCY

Use explicit state encoding.

Prefer a clean Moore-style FSM architecture.

Separate the Verilog into logical sections:

A. State declarations
B. State register
C. Timer/counter
D. Next-state combinational logic
E. Output combinational logic

==================================================
7. NORMAL STATE BEHAVIOR
========================

S_IDLE:

* Barrier UP
* Railway signal safe/green
* Warning OFF
* Buzzer OFF
* Emergency OFF
* Wait for train_approach

If train_approach = 1:
IDLE -> WARNING

S_WARNING:

* Railway signal RED
* Warning light ON
* Buzzer ON
* Barrier remains UP
* Warning timer runs

When warning timer expires:
WARNING -> CLOSING

S_CLOSING:

* Railway signal RED
* Warning ON
* Buzzer ON
* Barrier moving DOWN
* barrier_down = 1
* barrier_moving = 1

If obstacle_detected:
CLOSING -> SAFETY_HOLD

Otherwise when closing timer expires:
CLOSING -> CLOSED

S_CLOSED:

* Barrier DOWN
* Railway signal RED
* Warning ON
* Buzzer ON
* Wait for train crossing/presence

Then:
CLOSED -> TRAIN_PASSING

S_TRAIN_PASSING:

* Barrier remains DOWN
* Railway signal RED
* Train direction should be available for visualization
* Wait for train_departed

When train_departed:
TRAIN_PASSING -> OPENING

S_OPENING:

* Barrier moving UP
* barrier_up = 1
* barrier_moving = 1
* Railway crossing remains in a safe state
* Opening timer runs

When timer expires:
OPENING -> IDLE

S_SAFETY_HOLD:

This is the special safety feature.

If an obstacle is detected while the barrier is closing:

* Stop barrier closing
* Keep railway signal RED
* Keep warning light ON
* Keep buzzer ON
* Put the system in a safe hold condition

When obstacle_detected becomes 0:
SAFETY_HOLD -> CLOSING

S_EMERGENCY:

Emergency has highest priority.

When emergency_override is active:

* Railway signal RED
* Warning ON
* Buzzer ON
* Emergency indicator ON
* Barrier must not continue an unsafe closing operation
* Keep the system in EMERGENCY until the emergency condition is cleared/reset according to the safest implementation

==================================================
8. PRIORITY
===========

Implement a clear priority policy:

1. Reset
2. Emergency
3. Obstacle safety condition
4. Normal train operation

Avoid contradictory transitions.

Do not allow the controller to enter an unsafe state because two inputs are active simultaneously.

==================================================
9. TIMER
========

Implement a parameterized timer.

Use simulation-friendly values such as:

WARNING_TIME = 5
CLOSING_TIME = 4
OPENING_TIME = 4

Do NOT use huge counters that make simulation slow.

Reset the timer appropriately when entering a new state.

The timer must be synthesizable.

==================================================
10. TRAIN DIRECTION
===================

Support:

train_from_left
train_from_right

The web visualization should show:

TRAIN DIRECTION:
LEFT -> RIGHT

or:

TRAIN DIRECTION:
RIGHT -> LEFT

If both are active, handle the condition safely and document the behavior.

==================================================
11. VERILOG QUALITY
===================

Use synthesizable Verilog.

Avoid unnecessary SystemVerilog-specific constructs unless Icarus Verilog is configured appropriately.

Use clean:

always @(posedge clk)
always @(*)

where appropriate.

Use safe default assignments in combinational logic.

Avoid latches.

Avoid multiple procedural drivers for the same signal.

Make reset behavior deterministic.

Add comments explaining important sections.

==================================================
12. TESTBENCH
=============

Create:

tb/tb_railway_crossing_controller.v

The testbench must:

* Generate clock
* Apply reset
* Generate VCD
* Display useful simulation information
* Test normal operation
* Test train approaching from left
* Test train approaching from right
* Test warning timer
* Test closing
* Test closed state
* Test train passing
* Test train departure
* Test opening
* Test obstacle during closing
* Test SAFETY_HOLD
* Test obstacle clearance
* Test emergency override
* Test recovery/reset

Use $display statements.

Where practical, use self-checking PASS/FAIL conditions.

The simulation should clearly show state transitions.

Example:

============================================
SMART RAILWAY CROSSING SIMULATION
=================================

RESET
STATE: IDLE
BARRIER: UP

TRAIN APPROACH DETECTED
STATE: WARNING

WARNING COMPLETE
STATE: CLOSING

OBSTACLE DETECTED
STATE: SAFETY_HOLD

OBSTACLE CLEARED
STATE: CLOSING

BARRIER CLOSED
STATE: CLOSED

TRAIN PASSING
STATE: TRAIN_PASSING

TRAIN DEPARTED
STATE: OPENING

BARRIER OPEN
STATE: IDLE

TEST RESULT: PASS

============================================

==================================================
13. VCD
=======

Generate:

sim/railway_crossing.vcd

using:

$dumpfile("sim/railway_crossing.vcd");
$dumpvars(0, tb_railway_crossing_controller);

Include important internal and external signals.

==================================================
14. ASCII CONSOLE VISUALIZATION
===============================

Make the testbench output easy to understand.

Display something similar to:

+------------------------------------------+
|       SMART RAILWAY CROSSING             |
+------------------------------------------+
| TRAIN:              --->                 |
| FSM STATE:          CLOSING              |
| TIMER:              03                   |
| RAIL SIGNAL:        RED                  |
| BARRIER:            MOVING DOWN          |
| WARNING:            ON                   |
| BUZZER:             ON                   |
| OBSTACLE:           CLEAR                |
| EMERGENCY:          OFF                  |
+------------------------------------------+

When SAFETY_HOLD occurs, clearly display:

!!! SAFETY HOLD !!!
OBSTACLE DETECTED
BARRIER MOVEMENT STOPPED

When EMERGENCY occurs:

!!! EMERGENCY !!!
EMERGENCY OVERRIDE ACTIVE
RAIL SIGNAL: RED

==================================================
15. WEB APPLICATION
===================

Create a Flask web application.

It should provide a visual railway crossing simulation.

The page should include:

* Railway track
* Train
* Railway crossing
* Barrier
* Railway signal
* Warning lights
* Buzzer indicator
* FSM state
* Timer
* Train direction
* Obstacle status
* Emergency status

Provide controls/buttons:

[RESET]

[TRAIN APPROACH]

[TRAIN FROM LEFT]

[TRAIN FROM RIGHT]

[TRAIN DEPARTED]

[OBSTACLE DETECTED]

[CLEAR OBSTACLE]

[EMERGENCY]

[CLEAR EMERGENCY]

The UI should update the visual status.

==================================================
16. WEB DESIGN
==============

Make the interface look like an engineering simulation rather than a generic website.

Include:

* Dark/light readable interface
* Railway track visualization
* Animated or clearly changing train
* Barrier that visually changes between UP, DOWN and MOVING
* Red railway signal
* Warning indicators
* Status panel
* FSM state display
* Timer display
* Event log

Use CSS and JavaScript.

Do not use external frameworks unless necessary.

Prefer a self-contained implementation.

==================================================
17. IMPORTANT WEB/HDL ARCHITECTURE
==================================

Do NOT create an unrelated fake JavaScript FSM that contradicts the Verilog FSM.

The Verilog controller is the authoritative digital logic design.

The web application should represent the same FSM states and behavior.

If direct real-time Verilog-to-browser control is too complex for the environment, implement a clean demonstration interface that uses the same documented FSM behavior, and clearly document the separation.

Do not falsely claim that the browser is directly synthesizing hardware.

==================================================
18. SIMULATION SCRIPTS
======================

Create:

scripts/run_sim.sh

It should compile and run the testbench.

For example, conceptually:

iverilog ...
vvp ...

Create:

scripts/run_web.sh

to start the Flask application.

Make scripts executable if possible.

==================================================
19. AUTOMATIC VALIDATION
========================

After generating all files:

1. Compile the Verilog.
2. Run the testbench.
3. Check for syntax errors.
4. Check for simulation errors.
5. Confirm the VCD is generated.
6. Run Python syntax checks.
7. Check Flask imports.
8. Check that HTML/CSS/JS files exist.
9. Fix any errors you encounter.

Do NOT stop after generating the files.

Actually test the project.

If an error occurs, diagnose it and fix it.

Then rerun the relevant test.

Keep fixing until the project successfully compiles and the simulation completes.

==================================================
20. README
==========

Create a detailed README.md containing:

* Project title
* Abstract
* Problem statement
* Motivation
* Objectives
* Features
* System architecture
* Block diagram in ASCII
* Inputs
* Outputs
* FSM states
* FSM transition explanation
* Timer explanation
* Obstacle detection
* Emergency override
* Train direction
* Verilog architecture
* Testbench architecture
* Simulation commands
* GTKWave instructions
* Web simulator instructions
* Expected simulation behavior
* Advantages
* Limitations
* Future improvements
* Conclusion

Also include a section:

"How this project differs from a traffic-light controller"

Explain that the project controls railway crossing safety using barrier control, train detection, obstacle handling and emergency logic rather than road traffic lights.

==================================================
21. DOCUMENTATION FOR VIVA
==========================

At the bottom of README.md include:

"Viva Preparation"

with at least 15 questions and answers covering:

* What is an FSM?
* Why use an FSM here?
* Moore vs Mealy
* Why use a timer?
* Why is obstacle detection necessary?
* What happens during emergency?
* Why use a safety-hold state?
* What is the role of reset?
* What is the role of the testbench?
* What is VCD?
* What is GTKWave?
* Why use Icarus Verilog?
* How does train direction work?
* What happens if obstacle and train signals occur together?
* How is the web simulator related to the HDL?

==================================================
22. IMPORTANT DESIGN RULES
==========================

Do not:

* Turn this into a traffic light project.
* Copy an existing traffic controller and rename variables.
* Remove the FSM.
* Remove the timer.
* Remove the testbench.
* Remove VCD generation.
* Create an unnecessarily complicated hardware design.
* Use huge simulation delays.
* Claim physical hardware implementation.
* Leave compilation errors unresolved.
* Generate placeholder files without implementation.

Do:

* Make the project genuinely different.
* Keep it understandable for an ADLD student.
* Make the FSM the central design.
* Make the obstacle-detection feature meaningful.
* Make the emergency state meaningful.
* Make simulation easy to demonstrate.
* Make the web visualization attractive and educational.
* Keep all components consistent with each other.
* Test everything before finishing.

==================================================
23. FINAL RESPONSE FROM YOU
===========================

After completing the project, report:

1. Files created
2. FSM states
3. Main features
4. Compilation command used
5. Simulation command used
6. Whether simulation passed
7. VCD location
8. Web application command
9. Any assumptions made
10. Any remaining limitations

Do not just tell me what you WOULD build.

Actually create the files, implement the design, run the tests, fix errors, and leave the workspace in a working state.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/143a6808-013c-4c26-b144-953f080422e8).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
