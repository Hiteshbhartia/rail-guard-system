# Smart Railway Level-Crossing Controller with Obstacle Detection and Emergency Override

An ADLD / Digital Logic Design mini-project implemented as a **Moore finite state machine in Verilog HDL**, verified with an **Icarus Verilog self-checking testbench + GTKWave VCD**, and demonstrated through a **Flask web simulator** that mirrors the same FSM.

---

## Abstract

Unmanned and poorly automated railway level crossings are a major cause of accidents. This project designs a synthesizable digital controller that automatically protects a road/rail level crossing. On detecting an approaching train the controller turns the rail signal RED, activates warning lights and a buzzer, waits a configurable warning period, lowers the barrier, holds it closed while the train passes, and reopens it only after the train has departed. Two safety features are built into the FSM: a **SAFETY_HOLD** state that freezes barrier motion when an obstacle (vehicle/person) is detected under the boom, and an **EMERGENCY** state with the highest runtime priority that raises the barrier and latches the crossing in a protected condition until an operator acknowledges.

## Problem statement

Design and verify a digital controller that sequences a railway level crossing (signal, warning lamps, buzzer, barrier motor) from train-approach to train-departure, while guaranteeing that the barrier never closes onto an obstacle and that an operator can force the system into a safe emergency condition at any time.

## Motivation

* Manual gate operation depends on a gatekeeper and is error prone.
* Simple timer-based gates keep closing even if a vehicle is trapped on the crossing.
* A small, fully synthesizable FSM can implement the entire safety interlock at negligible hardware cost, with deterministic timing and deterministic reset behaviour.

## Objectives

1. Model the level-crossing sequence as an explicit, documented FSM.
2. Provide a parameterized, synthesizable timer for warning / closing / opening phases.
3. Implement obstacle-triggered barrier hold and automatic resume.
4. Implement a latched emergency override with a clear priority policy.
5. Detect and report train direction (left→right / right→left).
6. Verify everything with a self-checking testbench and waveform dump.
7. Visualize the same FSM in a browser for demonstration and viva.

## Features

* 8-state Moore FSM with explicit binary encoding.
* Parameterized timers: `WARNING_TIME = 5`, `CLOSING_TIME = 4`, `OPENING_TIME = 4` clock cycles.
* Obstacle detection → `S_SAFETY_HOLD` → automatic resume.
* Emergency override with highest priority and operator-acknowledged recovery.
* Train direction latch with a defined behaviour when both sensors fire.
* Asynchronous active-low reset, deterministic to `S_IDLE`.
* No latches, no multiple drivers, safe defaults in every combinational block.
* Self-checking testbench (42 checks), ASCII console dashboard, VCD dump.
* Flask + HTML/CSS/JS engineering-style visual simulator.

---

## System architecture

```
        SENSORS                     CONTROLLER (FSM)                 ACTUATORS
 ┌────────────────────┐     ┌──────────────────────────────┐   ┌────────────────────┐
 │ train_approach     │────▶│  D. Next-state logic          │──▶│ rail_signal_red    │
 │ train_from_left    │────▶│     (priority arbitration)    │   │ warning_light      │
 │ train_from_right   │────▶│              │                │   │ buzzer             │
 │ train_departed     │────▶│              ▼                │──▶│ barrier_up         │
 │ obstacle_detected  │────▶│  B. State register (posedge)  │   │ barrier_down       │
 │ emergency_override │────▶│              │                │   │ barrier_moving     │
 │ manual_reset       │────▶│              ▼                │──▶│ emergency_indicator│
 └────────────────────┘     │  C. Timer  ──▶ E. Moore output│   └────────────────────┘
   clk ─────────────────────▶│             logic            │
   rst_n ───────────────────▶└──────────────────────────────┘
                                     │  state_out, timer_out, train_dir_out
                                     ▼
                          Testbench / VCD / Web visualizer
```

### Crossing block diagram (ASCII)

```
        ┌────────┐                 ROAD                 ┌────────┐
        │ SIGNAL │                  ║                   │ WARN   │
        │  RED   │                  ║                   │ LAMPS  │
        └────────┘        ┌─────────╫─────────┐         └────────┘
                          │  BARRIER║ BARRIER │
  ====[ LEFT SENSOR ]=====╪═════════╫═════════╪=====[ RIGHT SENSOR ]====  RAIL
                          └─────────╫─────────┘
                            OBSTACLE SENSOR (inside crossing)
```

---

## Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1 | System clock; all sequential logic on `posedge`. |
| `rst_n` | 1 | Asynchronous active-low reset → `S_IDLE`, timer 0, direction cleared. |
| `train_approach` | 1 | Approach track-circuit: a train is announced. |
| `train_from_left` | 1 | Direction sensor on the left side of the crossing. |
| `train_from_right` | 1 | Direction sensor on the right side of the crossing. |
| `train_departed` | 1 | Exit sensor: the train has fully cleared the crossing. |
| `obstacle_detected` | 1 | IR / inductive-loop sensor inside the crossing area. |
| `emergency_override` | 1 | Operator emergency switch (level). |
| `manual_reset` | 1 | Operator acknowledge; releases the latched emergency. |

## Outputs

| Signal | Description |
|---|---|
| `warning_light` | Flashing road warning lamps. |
| `buzzer` | Audible warning. |
| `rail_signal_red` | 1 = RED (rail stop aspect), 0 = GREEN / safe. |
| `barrier_up` | Barrier is up, or the motor is commanded upward. |
| `barrier_down` | Barrier is down, or the motor is commanded downward. |
| `barrier_moving` | Barrier motor is energized. |
| `emergency_indicator` | Emergency beacon. |
| `state_out[3:0]` | Current FSM state (observability for TB/web). |
| `timer_out[7:0]` | Current timer value. |
| `train_dir_out[1:0]` | 00 none, 01 left→right, 10 right→left, 11 ambiguous. |

---

## FSM states

| Code | State | Barrier | Signal | Warn | Buzz | Emg |
|---|---|---|---|---|---|---|
| 0 | `S_IDLE` | UP | GREEN | off | off | off |
| 1 | `S_WARNING` | UP | RED | on | on | off |
| 2 | `S_CLOSING` | MOVING DOWN | RED | on | on | off |
| 3 | `S_CLOSED` | DOWN | RED | on | on | off |
| 4 | `S_TRAIN_PASSING` | DOWN | RED | on | off | off |
| 5 | `S_OPENING` | MOVING UP | RED | on | off | off |
| 6 | `S_SAFETY_HOLD` | FROZEN mid-travel | RED | on | on | off |
| 7 | `S_EMERGENCY` | MOVING UP (safe) | RED | on | on | **on** |

### FSM transition explanation

```
 rst_n=0 ─────────────────────────────────────▶ S_IDLE
 emergency_override=1 (from ANY state) ───────▶ S_EMERGENCY

 S_IDLE          --train_approach------------▶ S_WARNING
 S_WARNING       --obstacle_detected---------▶ S_SAFETY_HOLD
 S_WARNING       --timer = WARNING_TIME-1----▶ S_CLOSING
 S_CLOSING       --obstacle_detected---------▶ S_SAFETY_HOLD
 S_CLOSING       --timer = CLOSING_TIME-1----▶ S_CLOSED
 S_CLOSED        --unconditional-------------▶ S_TRAIN_PASSING
 S_TRAIN_PASSING --train_departed------------▶ S_OPENING
 S_OPENING       --train_approach------------▶ S_WARNING   (next train)
 S_OPENING       --timer = OPENING_TIME-1----▶ S_IDLE
 S_SAFETY_HOLD   --obstacle_detected=0-------▶ S_CLOSING
 S_EMERGENCY     --manual_reset--------------▶ S_OPENING   (barrier raised, then IDLE)
```

`S_CLOSED` advances unconditionally: once the boom is mechanically locked down, the
crossing is protected and the train is permitted to occupy it. The controller then
waits in `S_TRAIN_PASSING` for the exit sensor — there is no timeout that could open
the barrier under a train.

### Priority policy

1. **Reset** — asynchronous, wins over everything (handled in the flip-flops).
2. **Emergency** — checked before the state `case`, so it wins from every state.
3. **Obstacle safety** — checked before the timer expiry inside `S_WARNING`/`S_CLOSING`.
4. **Normal train operation** — timers and train sensors.

Because each level is tested before the next, two simultaneous inputs can never
produce a contradictory transition.

## Timer explanation

A single up-counter `timer` is cleared whenever `next_state != state`, so every
state starts counting from 0, and it saturates at its maximum instead of wrapping
(a wrap could otherwise re-trigger a comparison). Expiry flags
`warn_done`, `close_done`, `open_done` compare against
`WARNING_TIME-1`, `CLOSING_TIME-1`, `OPENING_TIME-1`. The values are parameters,
so real hardware can use large counts while simulation stays fast.

## Obstacle detection

If `obstacle_detected` rises while the barrier is closing (or before closing starts,
in `S_WARNING`), the FSM jumps to `S_SAFETY_HOLD`, which de-asserts `barrier_moving`,
`barrier_up` and `barrier_down`: the boom freezes exactly where it is, while the rail
signal stays RED and the warning + buzzer remain active. When the obstacle clears, the
FSM returns to `S_CLOSING` with a fresh timer, i.e. the closing travel restarts safely.

## Emergency override

`emergency_override` forces `S_EMERGENCY` from any state. There the barrier is commanded
**up** (never continue an unsafe closing), the rail signal stays RED, warning, buzzer and
the emergency beacon are on. Releasing the switch alone is **not** enough — the state is
latched until the operator presses `manual_reset`. Recovery goes through `S_OPENING`, so
the barrier is verifiably raised before the system can return to `S_IDLE`.

## Train direction

`train_from_left` → `01` (LEFT → RIGHT), `train_from_right` → `10` (RIGHT → LEFT).
If **both** are active the latch stores `11` (ambiguous). Documented behaviour: the
controller treats this as "a train is present from an unknown side" — protection is
unaffected (the crossing still closes normally); only the displayed arrow shows `<-??->`.
Direction is display/telemetry information and deliberately has no influence on the
safety sequence.

---

## Verilog architecture

`rtl/railway_crossing_controller.v` is split into five commented sections:

* **A. State declarations** — `localparam` binary encoding, direction encoding.
* **B. State register** — `always @(posedge clk or negedge rst_n)`.
* **C. Timer/counter** — cleared on state change, saturating, synthesizable.
* **D. Next-state logic** — one `always @(*)` with `next_state = state;` default.
* **E. Output logic** — one `always @(*)`, all outputs defaulted → no latches.

Each output is driven by exactly one procedural block (no multiple drivers) and the
outputs depend only on the state (Moore), so they are glitch-free relative to inputs.

## Testbench architecture

`tb/tb_railway_crossing_controller.v`:

* 10 ns clock, asynchronous reset sequence.
* `tick(n)` task to advance whole clock cycles.
* `check_state()` / `check_bit()` self-checking tasks that count PASS/FAIL.
* `show_panel()` ASCII dashboard task.
* A `always @(posedge clk)` monitor that prints every `>>> TRANSITION: A -> B`.
* Tests: reset, normal run from left, warning timer, closing, obstacle →
  SAFETY_HOLD, obstacle clearance, closed, train passing, departure, opening,
  train from right, emergency priority (even over an obstacle), emergency latching,
  manual-reset recovery, asynchronous reset mid-sequence.
* Final summary prints `TEST RESULT: PASS` when zero failures.

## Simulation commands

```bash
cd smart_railway_crossing
bash scripts/run_sim.sh
```

or manually:

```bash
iverilog -g2005 -Wall -o sim/railway_crossing.out \
    rtl/railway_crossing_controller.v tb/tb_railway_crossing_controller.v
vvp sim/railway_crossing.out
```

## GTKWave instructions

```bash
gtkwave sim/railway_crossing.vcd
```

Suggested signal order: `clk`, `rst_n`, `train_approach`, `train_from_left`,
`train_from_right`, `train_departed`, `obstacle_detected`, `emergency_override`,
`manual_reset`, then `state_out[3:0]` (set Data Format → Decimal), `timer_out[7:0]`,
`train_dir_out[1:0]`, then the outputs. Reading `state_out` as decimal gives the state
numbers listed in the FSM table above.

## Web simulator instructions

```bash
pip install -r requirements.txt     # or: python3 -m pip install flask
bash scripts/run_web.sh
# open http://127.0.0.1:5000
```

Buttons: RESET, TRAIN APPROACH, TRAIN FROM LEFT, TRAIN FROM RIGHT, TRAIN DEPARTED,
OBSTACLE DETECTED, CLEAR OBSTACLE, EMERGENCY, CLEAR EMERGENCY, MANUAL RESET (ACK),
plus RUN/STOP CLOCK. Level buttons stay asserted exactly like RTL ports.

### Web ↔ HDL relationship (honest statement)

The browser does **not** synthesize or execute hardware. `web/app.py` contains a
cycle-accurate **software mirror** of the same Moore FSM — identical states, encoding,
timer parameters, transition conditions and priority policy. One `/api/tick` call equals
one `posedge clk`. The Verilog RTL remains the authoritative design; the web app is a
demonstration/visualization layer.

## Expected simulation behaviour

```
============================================
SMART RAILWAY CROSSING SIMULATION
============================================
RESET                -> STATE: IDLE,          BARRIER: UP,   SIGNAL: GREEN
TRAIN APPROACH       -> STATE: WARNING        (lights + buzzer ON, barrier still UP)
WARNING COMPLETE     -> STATE: CLOSING        (barrier MOVING DOWN)
OBSTACLE DETECTED    -> STATE: SAFETY_HOLD    (motor stopped, signal RED)
OBSTACLE CLEARED     -> STATE: CLOSING
BARRIER CLOSED       -> STATE: CLOSED
                     -> STATE: TRAIN_PASSING
TRAIN DEPARTED       -> STATE: OPENING
BARRIER OPEN         -> STATE: IDLE
EMERGENCY            -> STATE: EMERGENCY      (latched until MANUAL RESET)
MANUAL RESET         -> STATE: OPENING -> IDLE
CHECKS RUN : 42
FAILURES   : 0
TEST RESULT: PASS
============================================
```

## Advantages

* Fully automatic, deterministic, gatekeeper-independent operation.
* Obstacle interlock prevents the boom from trapping a vehicle or person.
* Emergency override with latched recovery prevents accidental release.
* Small, cheap, synthesizable design (8 states + one small counter).
* Moore outputs are stable for a whole clock period — safe to drive relays.

## Limitations

* Simulation only; no physical hardware or FPGA board is claimed.
* Sensor inputs are assumed already debounced and metastability-synchronized.
* Single track, single crossing; no train-speed or block-section logic.
* Barrier position is modelled by a timer, not by real limit switches.
* Timer values are simulation-scale and must be re-parameterized for real clocks.

## Future improvements

* Two-flip-flop input synchronizers and debouncers for all field sensors.
* Real limit switches (`barrier_fully_up` / `barrier_fully_down`) instead of timers.
* Fault detection (motor stall, lamp failure) with a dedicated `S_FAULT` state.
* Multi-track support and a second crossing in a block-interlocking scheme.
* UART/SPI telemetry so the web dashboard can read a real FPGA instead of a mirror.
* Formal property checking: "barrier_moving never asserted while obstacle_detected".

## Conclusion

The project delivers a complete, verified ADLD design flow: an 8-state Moore FSM in
synthesizable Verilog, a parameterized timer, two genuine safety mechanisms
(obstacle hold and emergency override), a self-checking testbench with 42 passing
checks, a GTKWave-viewable VCD, and a browser visualizer that reproduces the same
behaviour for demonstration.

---

## How this project differs from a traffic-light controller

A traffic-light controller cycles road directions through GREEN → YELLOW → RED on a
fixed rotation; its "state" is simply which road has right of way, and its only real
input is a timer (sometimes a pedestrian request).

This controller is **not** a rotation. It is an event-driven safety interlock for a
road/rail intersection:

* It drives a **mechanical actuator** (barrier motor) with explicit
  `barrier_up` / `barrier_down` / `barrier_moving` motor states, which a traffic light
  has no equivalent of.
* Its sequence is triggered by **external train sensors** (approach, direction, exit),
  not by a free-running cycle; it can wait indefinitely in `S_TRAIN_PASSING`.
* It contains an **obstacle interlock** (`S_SAFETY_HOLD`) that freezes an actuator
  mid-travel and resumes — a traffic light never freezes mid-transition.
* It contains a **latched emergency state** with operator acknowledgement and a
  forced safe-raise recovery path.
* It has a **direction-detection datapath** (`train_dir` latch) with a documented
  ambiguous case.
* The safety requirement is inverted: a traffic light's failure mode is congestion,
  while here the FSM must guarantee the barrier never closes onto an obstacle and
  never opens while a train occupies the crossing.

No state, signal or behaviour is a renamed traffic-light element.

---

# Viva Preparation

**1. What is an FSM?**
A Finite State Machine is a sequential circuit that is always in exactly one of a
finite set of states. A state register holds the present state; combinational
next-state logic computes the following state from the present state and the inputs;
output logic derives the outputs. Here it has 8 states encoded in 4 bits.

**2. Why use an FSM for a level crossing?**
The crossing sequence is inherently ordered (warn → close → hold → open) and must never
skip a step. An FSM makes every legal transition explicit, makes illegal transitions
impossible, and gives deterministic, provable behaviour — exactly what a safety
interlock requires.

**3. Moore vs Mealy — which is used and why?**
Moore: outputs depend only on the current state. This design is Moore. Outputs are
therefore stable for a full clock period and cannot glitch when a sensor input jitters,
which matters because these outputs drive relays, lamps and a motor. A Mealy machine
would react one cycle earlier but could produce input-driven glitches.

**4. Why use a timer?**
Physical actions take time: pedestrians and vehicles need a warning period before the
boom moves, and the boom needs travel time. The timer counts clock cycles inside each
timed state (`WARNING_TIME`, `CLOSING_TIME`, `OPENING_TIME`) and generates the expiry
condition for the transition. It is a parameter so simulation is fast and real hardware
can use realistic values.

**5. Why is obstacle detection necessary?**
Without it a purely time-driven boom would descend onto a vehicle or person trapped on
the crossing. The obstacle sensor lets the FSM stop the motor mid-travel
(`S_SAFETY_HOLD`) while keeping the rail signal RED, then resume automatically.

**6. What happens during emergency?**
`emergency_override` is evaluated before the state `case`, so from any state the FSM
enters `S_EMERGENCY`: signal RED, warning ON, buzzer ON, emergency beacon ON, and the
barrier is commanded upward rather than continuing to close. The state is latched: it
is left only when the operator asserts `manual_reset`, and recovery goes through
`S_OPENING`.

**7. Why use a safety-hold state instead of just stopping the motor?**
A separate state makes the safe condition explicit and observable (it appears in
`state_out`, in the waveform and in the log), and it defines exactly how the system
resumes. Just gating the motor signal would leave the FSM believing it is still closing
and the timer would expire, declaring the boom "closed" when it is not.

**8. What is the role of reset?**
`rst_n` is asynchronous and active-low. It forces `state = S_IDLE`, clears the timer and
the direction latch, guaranteeing a known, safe power-up condition (barrier up, signal
green) regardless of the state the flip-flops power up in.

**9. What is the role of the testbench?**
The testbench is non-synthesizable Verilog that instantiates the design, generates the
clock and reset, applies stimulus, observes the outputs, and compares them against
expected values. Here it also counts checks and prints `TEST RESULT: PASS/FAIL`, so
verification is automatic instead of eyeballing waveforms.

**10. What is a VCD?**
Value Change Dump — a standard ASCII file that records every signal value change with a
timestamp. It is produced by `$dumpfile` and `$dumpvars` and is the input to waveform
viewers.

**11. What is GTKWave?**
A free, open-source waveform viewer that opens VCD files, letting you inspect signal
timing, state transitions and bus values graphically.

**12. Why use Icarus Verilog?**
It is a free, open-source Verilog compiler and simulator (`iverilog` compiles,
`vvp` runs) available on any Linux machine, so the whole project can be reproduced
without proprietary EDA licences.

**13. How does train direction work?**
Two side sensors feed a 2-bit latch: left only → `01` (LEFT → RIGHT), right only → `10`
(RIGHT → LEFT), both → `11` (ambiguous), and it clears to `00` in `S_IDLE` when no train
is announced. It is telemetry used for display and does not alter the safety sequence.

**14. What happens if obstacle and train signals occur together?**
The priority policy decides: reset > emergency > obstacle > normal train operation.
So with a train announced and an obstacle present, the FSM goes to (or stays in)
`S_SAFETY_HOLD` with the signal RED — the train is stopped by the red aspect while the
boom refuses to trap the obstacle. There is no contradictory transition because the
obstacle condition is tested before the timer-expiry condition.

**15. How is the web simulator related to the HDL?**
It is a visual demonstration layer, not hardware. `web/app.py` implements a
cycle-accurate software mirror of the same FSM (same states, encoding, parameters,
transitions and priorities) and one `/api/tick` corresponds to one `posedge clk`. The
Verilog RTL, verified by the testbench and the VCD, remains the authoritative design.

**16. Are there any latches in the design?**
No. Both combinational blocks assign a default value to every variable they drive
(`next_state = state;` and all outputs cleared) before the `case`, so every branch
assigns every signal and no storage is inferred.

**17. Why is `S_CLOSED` unconditional?**
Once the boom is locked down the crossing is protected, so the controller immediately
moves to `S_TRAIN_PASSING` and waits there for the exit sensor. Using a timeout instead
could open the barrier while a train is still on the crossing.
