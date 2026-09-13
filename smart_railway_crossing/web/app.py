"""
Smart Railway Level-Crossing Controller - Flask web simulator.

IMPORTANT / HONEST ARCHITECTURE NOTE
------------------------------------
The authoritative digital design is the Verilog RTL in
rtl/railway_crossing_controller.v, verified by the Icarus Verilog testbench.

This Flask application does NOT synthesize or execute hardware. It contains a
cycle-accurate *software mirror* of the very same Moore FSM (same states, same
encoding, same timer parameters, same priority policy) so that the behaviour
can be demonstrated visually in a browser. Every clock "tick" requested by the
browser calls step() once, exactly like one posedge clk in the RTL.

If the RTL is modified, update FSM_TRANSITIONS/OUTPUTS here to match.
"""

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

# ---------------------------------------------------------------- parameters
WARNING_TIME = 5
CLOSING_TIME = 4
OPENING_TIME = 4

# ---------------------------------------------------------------- state codes
S_IDLE, S_WARNING, S_CLOSING, S_CLOSED = 0, 1, 2, 3
S_TRAIN_PASSING, S_OPENING, S_SAFETY_HOLD, S_EMERGENCY = 4, 5, 6, 7

STATE_NAMES = {
    S_IDLE: "S_IDLE",
    S_WARNING: "S_WARNING",
    S_CLOSING: "S_CLOSING",
    S_CLOSED: "S_CLOSED",
    S_TRAIN_PASSING: "S_TRAIN_PASSING",
    S_OPENING: "S_OPENING",
    S_SAFETY_HOLD: "S_SAFETY_HOLD",
    S_EMERGENCY: "S_EMERGENCY",
}

DIR_NONE, DIR_L2R, DIR_R2L, DIR_BOTH = 0, 1, 2, 3
DIR_TEXT = {
    DIR_NONE: "NONE",
    DIR_L2R: "LEFT -> RIGHT",
    DIR_R2L: "RIGHT -> LEFT",
    DIR_BOTH: "AMBIGUOUS (BOTH SENSORS)",
}


class RailwayCrossingFSM:
    """Software mirror of railway_crossing_controller.v (one step == one clk)."""

    INPUT_NAMES = (
        "train_approach",
        "train_from_left",
        "train_from_right",
        "train_departed",
        "obstacle_detected",
        "emergency_override",
        "manual_reset",
    )

    def __init__(self):
        self.reset(hard=True)

    # ------------------------------------------------------------ reset
    def reset(self, hard=False):
        self.state = S_IDLE
        self.timer = 0
        self.train_dir = DIR_NONE
        self.cycle = 0
        self.log = ["[RESET] rst_n asserted -> S_IDLE"]
        if hard:
            self.inputs = {name: 0 for name in self.INPUT_NAMES}
        else:
            for name in ("manual_reset",):
                self.inputs[name] = 0

    # ------------------------------------------------------------ inputs
    def set_input(self, name, value):
        if name in self.INPUT_NAMES:
            self.inputs[name] = 1 if value else 0
            self.add_log("[INPUT] %s = %d" % (name, self.inputs[name]))

    def add_log(self, text):
        self.log.append(text)
        self.log = self.log[-60:]

    # ------------------------------------------------- D. next-state logic
    def next_state(self):
        i = self.inputs
        s = self.state

        # priority 2: emergency override (priority 1 = reset, handled outside)
        if i["emergency_override"]:
            return S_EMERGENCY

        if s == S_IDLE:
            return S_WARNING if i["train_approach"] else S_IDLE
        if s == S_WARNING:
            if i["obstacle_detected"]:
                return S_SAFETY_HOLD
            return S_CLOSING if self.timer >= WARNING_TIME - 1 else S_WARNING
        if s == S_CLOSING:
            if i["obstacle_detected"]:
                return S_SAFETY_HOLD
            return S_CLOSED if self.timer >= CLOSING_TIME - 1 else S_CLOSING
        if s == S_CLOSED:
            return S_TRAIN_PASSING
        if s == S_TRAIN_PASSING:
            return S_OPENING if i["train_departed"] else S_TRAIN_PASSING
        if s == S_OPENING:
            if i["train_approach"]:
                return S_WARNING
            return S_IDLE if self.timer >= OPENING_TIME - 1 else S_OPENING
        if s == S_SAFETY_HOLD:
            return S_CLOSING if not i["obstacle_detected"] else S_SAFETY_HOLD
        if s == S_EMERGENCY:
            return S_OPENING if i["manual_reset"] else S_EMERGENCY
        return S_IDLE

    # ------------------------------------------------- E. Moore outputs
    def outputs(self):
        s = self.state
        o = dict(
            warning_light=0,
            buzzer=0,
            rail_signal_red=0,
            barrier_up=0,
            barrier_down=0,
            barrier_moving=0,
            emergency_indicator=0,
        )
        if s == S_IDLE:
            o["barrier_up"] = 1
        elif s == S_WARNING:
            o.update(rail_signal_red=1, warning_light=1, buzzer=1, barrier_up=1)
        elif s == S_CLOSING:
            o.update(rail_signal_red=1, warning_light=1, buzzer=1,
                     barrier_down=1, barrier_moving=1)
        elif s == S_CLOSED:
            o.update(rail_signal_red=1, warning_light=1, buzzer=1, barrier_down=1)
        elif s == S_TRAIN_PASSING:
            o.update(rail_signal_red=1, warning_light=1, barrier_down=1)
        elif s == S_OPENING:
            o.update(rail_signal_red=1, warning_light=1, barrier_up=1, barrier_moving=1)
        elif s == S_SAFETY_HOLD:
            o.update(rail_signal_red=1, warning_light=1, buzzer=1)
        elif s == S_EMERGENCY:
            o.update(rail_signal_red=1, warning_light=1, buzzer=1,
                     emergency_indicator=1, barrier_up=1, barrier_moving=1)
        return o

    # ------------------------------------------------- one rising clock edge
    def step(self):
        i = self.inputs
        nxt = self.next_state()

        # direction latch (same logic as the RTL)
        if i["train_from_left"] and i["train_from_right"]:
            self.train_dir = DIR_BOTH
        elif i["train_from_left"]:
            self.train_dir = DIR_L2R
        elif i["train_from_right"]:
            self.train_dir = DIR_R2L
        elif self.state == S_IDLE and not i["train_approach"]:
            self.train_dir = DIR_NONE

        if nxt != self.state:
            self.add_log("[T=%d] %s -> %s" % (self.cycle, STATE_NAMES[self.state],
                                              STATE_NAMES[nxt]))
            self.timer = 0
        elif self.timer < 255:
            self.timer += 1

        self.state = nxt
        self.cycle += 1

        # manual_reset behaves like an operator push-button: auto-release
        if i["manual_reset"]:
            i["manual_reset"] = 0
        return self.snapshot()

    # ------------------------------------------------------------ snapshot
    def snapshot(self):
        data = self.outputs()
        data.update(
            state=self.state,
            state_name=STATE_NAMES[self.state],
            timer=self.timer,
            cycle=self.cycle,
            train_dir=self.train_dir,
            train_dir_text=DIR_TEXT[self.train_dir],
            inputs=dict(self.inputs),
            log=self.log[-20:],
            params=dict(WARNING_TIME=WARNING_TIME,
                        CLOSING_TIME=CLOSING_TIME,
                        OPENING_TIME=OPENING_TIME),
        )
        return data


FSM = RailwayCrossingFSM()


# ------------------------------------------------------------------- routes
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/state")
def api_state():
    return jsonify(FSM.snapshot())


@app.route("/api/tick", methods=["POST"])
def api_tick():
    return jsonify(FSM.step())


@app.route("/api/input", methods=["POST"])
def api_input():
    payload = request.get_json(force=True, silent=True) or {}
    FSM.set_input(payload.get("name", ""), payload.get("value", 0))
    return jsonify(FSM.snapshot())


@app.route("/api/reset", methods=["POST"])
def api_reset():
    FSM.reset(hard=True)
    return jsonify(FSM.snapshot())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
