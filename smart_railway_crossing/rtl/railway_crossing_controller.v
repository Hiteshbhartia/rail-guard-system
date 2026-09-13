//============================================================================
//  Smart Railway Level-Crossing Controller with Obstacle Detection
//  and Emergency Override
//----------------------------------------------------------------------------
//  Moore-style Finite State Machine, fully synthesizable Verilog-2001.
//
//  Sections:
//    A. Parameters & state declarations
//    B. State register (sequential)
//    C. Timer / counter (sequential)
//    D. Next-state combinational logic
//    E. Output combinational logic (Moore: depends on state only)
//============================================================================

`timescale 1ns / 1ps

module railway_crossing_controller #(
    // Simulation-friendly timer values (in clock cycles)
    parameter WARNING_TIME = 5,   // siren / warning period before barrier moves
    parameter CLOSING_TIME = 4,   // time the barrier needs to travel down
    parameter OPENING_TIME = 4,   // time the barrier needs to travel up
    parameter TIMER_WIDTH  = 8
) (
    //------------------------------------------------------------------ inputs
    input  wire                    clk,                // system clock
    input  wire                    rst_n,              // async active-low reset
    input  wire                    train_approach,     // approach sensor (track circuit)
    input  wire                    train_from_left,    // direction sensor, left  side
    input  wire                    train_from_right,   // direction sensor, right side
    input  wire                    train_departed,     // exit sensor: train has cleared
    input  wire                    obstacle_detected,  // IR/loop sensor inside crossing
    input  wire                    emergency_override, // operator emergency switch
    input  wire                    manual_reset,       // operator acknowledge / release

    //----------------------------------------------------------------- outputs
    output reg                     warning_light,      // flashing warning lamps
    output reg                     buzzer,             // audible warning
    output reg                     rail_signal_red,    // 1 = RED (stop), 0 = GREEN (safe)
    output reg                     barrier_up,         // barrier is up / going up
    output reg                     barrier_down,       // barrier is down / going down
    output reg                     barrier_moving,     // barrier motor is running
    output reg                     emergency_indicator,// emergency beacon

    //------------------------------------------- observability (TB / web view)
    output wire [3:0]              state_out,          // current FSM state
    output wire [TIMER_WIDTH-1:0]  timer_out,          // current timer value
    output wire [1:0]              train_dir_out       // latched train direction
);

    //========================================================================
    // A. STATE DECLARATIONS  (explicit binary encoding)
    //========================================================================
    localparam [3:0] S_IDLE          = 4'd0,
                     S_WARNING       = 4'd1,
                     S_CLOSING       = 4'd2,
                     S_CLOSED        = 4'd3,
                     S_TRAIN_PASSING = 4'd4,
                     S_OPENING       = 4'd5,
                     S_SAFETY_HOLD   = 4'd6,
                     S_EMERGENCY     = 4'd7;

    // Train direction encoding
    localparam [1:0] DIR_NONE  = 2'b00,
                     DIR_L2R   = 2'b01,  // left  -> right
                     DIR_R2L   = 2'b10,  // right -> left
                     DIR_BOTH  = 2'b11;  // both sensors active -> treated as unknown
                                         // (safe: crossing is still closed)

    reg [3:0]            state, next_state;
    reg [TIMER_WIDTH-1:0] timer;
    reg [1:0]            train_dir;

    assign state_out     = state;
    assign timer_out     = timer;
    assign train_dir_out = train_dir;

    // Timer expiry flags (one per timed state)
    wire warn_done  = (timer >= (WARNING_TIME - 1));
    wire close_done = (timer >= (CLOSING_TIME - 1));
    wire open_done  = (timer >= (OPENING_TIME - 1));

    //========================================================================
    // B. STATE REGISTER
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;          // deterministic reset state
        else
            state <= next_state;
    end

    //========================================================================
    // C. TIMER / COUNTER
    //     Cleared whenever the FSM changes state, otherwise counts up and
    //     saturates so it can never wrap around into an unsafe comparison.
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= {TIMER_WIDTH{1'b0}};
        else if (next_state != state)
            timer <= {TIMER_WIDTH{1'b0}};
        else if (timer != {TIMER_WIDTH{1'b1}})
            timer <= timer + 1'b1;
    end

    //========================================================================
    //     TRAIN DIRECTION LATCH
    //     Sampled while the train is being announced; cleared back in IDLE
    //     once no approach is pending.
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            train_dir <= DIR_NONE;
        end else begin
            case ({train_from_left, train_from_right})
                2'b10: train_dir <= DIR_L2R;
                2'b01: train_dir <= DIR_R2L;
                2'b11: train_dir <= DIR_BOTH; // ambiguous: keep crossing protected
                default: if ((state == S_IDLE) && !train_approach)
                             train_dir <= DIR_NONE;
            endcase
        end
    end

    //========================================================================
    // D. NEXT-STATE COMBINATIONAL LOGIC
    //     Priority: 1) reset (handled in the flops)
    //               2) emergency_override
    //               3) obstacle safety condition
    //               4) normal train operation
    //========================================================================
    always @(*) begin
        next_state = state;                       // safe default: hold state

        if (emergency_override) begin
            next_state = S_EMERGENCY;             // highest runtime priority
        end else begin
            case (state)
                S_IDLE:
                    if (train_approach)
                        next_state = S_WARNING;

                S_WARNING:
                    if (obstacle_detected)
                        next_state = S_SAFETY_HOLD;   // never start closing on an obstacle
                    else if (warn_done)
                        next_state = S_CLOSING;

                S_CLOSING:
                    if (obstacle_detected)
                        next_state = S_SAFETY_HOLD;   // stop the barrier immediately
                    else if (close_done)
                        next_state = S_CLOSED;

                S_CLOSED:
                    next_state = S_TRAIN_PASSING;     // barrier locked, train may cross

                S_TRAIN_PASSING:
                    if (train_departed)
                        next_state = S_OPENING;

                S_OPENING:
                    if (train_approach)
                        next_state = S_WARNING;       // next train already announced
                    else if (open_done)
                        next_state = S_IDLE;

                S_SAFETY_HOLD:
                    if (!obstacle_detected)
                        next_state = S_CLOSING;       // resume closing when clear

                S_EMERGENCY:
                    // Leave emergency only when the override is released AND the
                    // operator acknowledges with manual_reset. The barrier is then
                    // raised through OPENING, never dropped directly.
                    if (manual_reset)
                        next_state = S_OPENING;

                default:
                    next_state = S_IDLE;              // unreachable -> fail safe
            endcase
        end
    end

    //========================================================================
    // E. OUTPUT COMBINATIONAL LOGIC (Moore)
    //     Every output is assigned a default first -> no latches inferred.
    //========================================================================
    always @(*) begin
        warning_light       = 1'b0;
        buzzer              = 1'b0;
        rail_signal_red     = 1'b0;
        barrier_up          = 1'b0;
        barrier_down        = 1'b0;
        barrier_moving      = 1'b0;
        emergency_indicator = 1'b0;

        case (state)
            S_IDLE: begin
                barrier_up      = 1'b1;          // road open, rail signal green
            end

            S_WARNING: begin
                rail_signal_red = 1'b1;
                warning_light   = 1'b1;
                buzzer          = 1'b1;
                barrier_up      = 1'b1;          // still up during the warning period
            end

            S_CLOSING: begin
                rail_signal_red = 1'b1;
                warning_light   = 1'b1;
                buzzer          = 1'b1;
                barrier_down    = 1'b1;
                barrier_moving  = 1'b1;
            end

            S_CLOSED: begin
                rail_signal_red = 1'b1;
                warning_light   = 1'b1;
                buzzer          = 1'b1;
                barrier_down    = 1'b1;
            end

            S_TRAIN_PASSING: begin
                rail_signal_red = 1'b1;
                warning_light   = 1'b1;
                barrier_down    = 1'b1;
            end

            S_OPENING: begin
                rail_signal_red = 1'b1;          // stays red until fully open
                warning_light   = 1'b1;
                barrier_up      = 1'b1;
                barrier_moving  = 1'b1;
            end

            S_SAFETY_HOLD: begin
                rail_signal_red = 1'b1;
                warning_light   = 1'b1;
                buzzer          = 1'b1;
                // barrier frozen mid-travel: no up, no down, motor stopped
            end

            S_EMERGENCY: begin
                rail_signal_red     = 1'b1;
                warning_light       = 1'b1;
                buzzer              = 1'b1;
                emergency_indicator = 1'b1;
                barrier_up          = 1'b1;      // never continue an unsafe closing
                barrier_moving      = 1'b1;
            end

            default: begin
                rail_signal_red = 1'b1;          // fail safe
            end
        endcase
    end

endmodule
