/* Smart Railway Crossing - browser front-end.
   All FSM decisions are made by the Python mirror in web/app.py, which in turn
   mirrors rtl/railway_crossing_controller.v. This file only renders state. */

const STATES = ["S_IDLE","S_WARNING","S_CLOSING","S_CLOSED",
                "S_TRAIN_PASSING","S_OPENING","S_SAFETY_HOLD","S_EMERGENCY"];

const $ = (id) => document.getElementById(id);
let running = false;
let timerHandle = null;
let latest = null;

// build FSM map chips
$("fsm-map").innerHTML = STATES.map(s =>
  `<span data-state="${s}">${s.replace("S_","")}</span>`).join("");

async function post(url, body) {
  const r = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(body || {})
  });
  return r.json();
}

function setLed(el, on, cls) {
  el.className = on ? ("on " + (cls || "")) : "";
}

function render(d) {
  latest = d;
  $("cycle").textContent = d.cycle;
  $("timer").textContent = String(d.timer).padStart(2, "0");
  $("state-name").textContent = d.state_name;
  $("state-name").className = "state-big" +
    (d.state_name === "S_EMERGENCY" ? " alert" :
     d.state_name === "S_SAFETY_HOLD" ? " hold" : "");

  // timer bar relative to the limit of the current state
  const p = d.params;
  const limit = d.state_name === "S_WARNING" ? p.WARNING_TIME
              : d.state_name === "S_CLOSING" ? p.CLOSING_TIME
              : d.state_name === "S_OPENING" ? p.OPENING_TIME : 0;
  $("timer-fill").style.width = limit ? Math.min(100, (d.timer + 1) / limit * 100) + "%" : "0%";

  // output LEDs
  setLed($("o-red"), d.rail_signal_red, "danger");
  setLed($("o-warn"), d.warning_light, "warnc");
  setLed($("o-buzz"), d.buzzer, "warnc");
  setLed($("o-up"), d.barrier_up);
  setLed($("o-down"), d.barrier_down);
  setLed($("o-moving"), d.barrier_moving);
  setLed($("o-emg"), d.emergency_indicator, "danger");
  setLed($("o-obs"), d.inputs.obstacle_detected, "warnc");

  // fsm map
  document.querySelectorAll("#fsm-map span").forEach(el =>
    el.classList.toggle("active", el.dataset.state === d.state_name));

  // signal lamps
  $("lamp-red").classList.toggle("on", !!d.rail_signal_red);
  $("lamp-green").classList.toggle("on", !d.rail_signal_red);
  $("warn-a").classList.toggle("on", !!d.warning_light && d.cycle % 2 === 0);
  $("warn-b").classList.toggle("on", !!d.warning_light && d.cycle % 2 === 1);

  // barrier position
  const closedStates = ["S_CLOSED", "S_TRAIN_PASSING"];
  const down = closedStates.includes(d.state_name) || d.state_name === "S_CLOSING";
  document.querySelectorAll(".barrier").forEach(b => {
    b.classList.toggle("down", down);
    b.classList.toggle("held", d.state_name === "S_SAFETY_HOLD");
    b.style.transitionDuration = d.barrier_moving ? "1.2s" : "0.4s";
  });
  let bText = "UP";
  if (d.barrier_moving && d.barrier_down) bText = "MOVING DOWN";
  else if (d.barrier_moving && d.barrier_up) bText = "MOVING UP";
  else if (d.barrier_down) bText = "DOWN";
  else if (!d.barrier_up) bText = "HELD (MID-TRAVEL)";
  $("barrier-text").textContent = bText;

  // train animation
  const train = $("train");
  const rightBound = d.train_dir === 1;          // LEFT -> RIGHT
  train.classList.toggle("flip", d.train_dir === 2);
  let pos = -260;
  if (["S_WARNING","S_CLOSING","S_SAFETY_HOLD"].includes(d.state_name)) pos = -120;
  else if (d.state_name === "S_CLOSED") pos = 60;
  else if (d.state_name === "S_TRAIN_PASSING") pos = 340;
  else if (d.state_name === "S_OPENING") pos = 900;
  if (d.train_dir === 2 && pos > -260) pos = 900 - pos;   // mirror for R->L
  if (d.train_dir === 0) pos = -260;
  train.style.left = pos + "px";
  $("dir-text").textContent = d.train_dir_text;

  $("obstacle").classList.toggle("show", !!d.inputs.obstacle_detected);
  $("emergency-flash").classList.toggle("show", !!d.emergency_indicator);

  // buttons reflect level inputs
  document.querySelectorAll("[data-toggle]").forEach(b =>
    b.classList.toggle("active", !!d.inputs[b.dataset.toggle]));
  document.querySelectorAll("[data-set]").forEach(b =>
    b.classList.toggle("active",
      d.inputs[b.dataset.set] === Number(b.dataset.value) && b.dataset.value === "1"));

  const log = $("log");
  log.textContent = d.log.join("\n");
  log.scrollTop = log.scrollHeight;
}

// ---------------------------------------------------------------- controls
document.addEventListener("click", async (e) => {
  const b = e.target.closest("button");
  if (!b) return;

  if (b.id === "btn-run") { toggleRun(); return; }
  if (b.dataset.action === "reset") { render(await post("/api/reset")); return; }

  if (b.dataset.toggle) {
    const name = b.dataset.toggle;
    render(await post("/api/input", {name, value: latest.inputs[name] ? 0 : 1}));
  } else if (b.dataset.set) {
    render(await post("/api/input", {name: b.dataset.set, value: Number(b.dataset.value)}));
  } else if (b.dataset.pulse) {
    await post("/api/input", {name: b.dataset.pulse, value: 1});
    render(await post("/api/tick"));      // consumed by exactly one clock edge
  }
});

function toggleRun() {
  running = !running;
  $("btn-run").classList.toggle("running", running);
  $("btn-run").textContent = running ? "STOP CLOCK" : "RUN CLOCK";
  if (running) timerHandle = setInterval(async () => render(await post("/api/tick")), 600);
  else clearInterval(timerHandle);
}

// boot
(async () => {
  render(await (await fetch("/api/state")).json());
  toggleRun();
})();
