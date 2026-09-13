//============================================================================
//  Testbench : tb_railway_crossing_controller.v
//  Self-checking testbench with ASCII console visualization + VCD dump.
//============================================================================

`timescale 1ns / 1ps

module tb_railway_crossing_controller;

    // ---------------------------------------------------------------- signals
    reg  clk, rst_n;
    reg  train_approach, train_from_left, train_from_right, train_departed;
    reg  obstacle_detected, emergency_override, manual_reset;

    wire warning_light, buzzer, rail_signal_red;
    wire barrier_up, barrier_down, barrier_moving, emergency_indicator;
    wire [3:0] state_out;
    wire [7:0] timer_out;
    wire [1:0] train_dir_out;

    integer errors = 0;
    integer checks = 0;

    localparam [3:0] S_IDLE          = 4'd0,
                     S_WARNING       = 4'd1,
                     S_CLOSING       = 4'd2,
                     S_CLOSED        = 4'd3,
                     S_TRAIN_PASSING = 4'd4,
                     S_OPENING       = 4'd5,
                     S_SAFETY_HOLD   = 4'd6,
                     S_EMERGENCY     = 4'd7;

    // ---------------------------------------------------------------- DUT
    railway_crossing_controller #(
        .WARNING_TIME(5),
        .CLOSING_TIME(4),
        .OPENING_TIME(4)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .train_approach(train_approach),
        .train_from_left(train_from_left),
        .train_from_right(train_from_right),
        .train_departed(train_departed),
        .obstacle_detected(obstacle_detected),
        .emergency_override(emergency_override),
        .manual_reset(manual_reset),
        .warning_light(warning_light),
        .buzzer(buzzer),
        .rail_signal_red(rail_signal_red),
        .barrier_up(barrier_up),
        .barrier_down(barrier_down),
        .barrier_moving(barrier_moving),
        .emergency_indicator(emergency_indicator),
        .state_out(state_out),
        .timer_out(timer_out),
        .train_dir_out(train_dir_out)
    );

    // ---------------------------------------------------------------- clock
    initial clk = 1'b0;
    always #5 clk = ~clk;          // 100 MHz-ish: 10 ns period

    // ---------------------------------------------------------------- helpers
    function [127:0] state_name;
        input [3:0] s;
        begin
            case (s)
                S_IDLE:          state_name = "IDLE";
                S_WARNING:       state_name = "WARNING";
                S_CLOSING:       state_name = "CLOSING";
                S_CLOSED:        state_name = "CLOSED";
                S_TRAIN_PASSING: state_name = "TRAIN_PASSING";
                S_OPENING:       state_name = "OPENING";
                S_SAFETY_HOLD:   state_name = "SAFETY_HOLD";
                S_EMERGENCY:     state_name = "EMERGENCY";
                default:         state_name = "UNKNOWN";
            endcase
        end
    endfunction

    function [63:0] dir_arrow;
        input [1:0] d;
        begin
            case (d)
                2'b01:   dir_arrow = "  --->  ";
                2'b10:   dir_arrow = "  <---  ";
                2'b11:   dir_arrow = " <-??-> ";
                default: dir_arrow = "  ----  ";
            endcase
        end
    endfunction

    function [95:0] barrier_text;
        begin
            if (barrier_moving && barrier_down)    barrier_text = "MOVING DOWN";
            else if (barrier_moving && barrier_up) barrier_text = "MOVING UP  ";
            else if (barrier_down)                 barrier_text = "DOWN       ";
            else if (barrier_up)                   barrier_text = "UP         ";
            else                                   barrier_text = "HELD       ";
        end
    endfunction

    task show_panel;
        begin
            $display("+------------------------------------------+");
            $display("|       SMART RAILWAY CROSSING             |");
            $display("+------------------------------------------+");
            $display("| TRAIN:              %0s                 ", dir_arrow(train_dir_out));
            $display("| FSM STATE:          %0s", state_name(state_out));
            $display("| TIMER:              %02d", timer_out);
            $display("| RAIL SIGNAL:        %0s", rail_signal_red ? "RED" : "GREEN");
            $display("| BARRIER:            %0s", barrier_text());
            $display("| WARNING:            %0s", warning_light ? "ON" : "OFF");
            $display("| BUZZER:             %0s", buzzer ? "ON" : "OFF");
            $display("| OBSTACLE:           %0s", obstacle_detected ? "DETECTED" : "CLEAR");
            $display("| EMERGENCY:          %0s", emergency_indicator ? "ACTIVE" : "OFF");
            $display("+------------------------------------------+");
            if (state_out == S_SAFETY_HOLD) begin
                $display("!!! SAFETY HOLD !!!");
                $display("OBSTACLE DETECTED");
                $display("BARRIER MOVEMENT STOPPED");
            end
            if (state_out == S_EMERGENCY) begin
                $display("!!! EMERGENCY !!!");
                $display("EMERGENCY OVERRIDE ACTIVE");
                $display("RAIL SIGNAL: RED");
            end
            $display("");
        end
    endtask

    task check_state;
        input [3:0] expected;
        input [255:0] label;
        begin
            checks = checks + 1;
            if (state_out === expected)
                $display("[PASS] %0s : STATE = %0s  (t=%0t)", label, state_name(state_out), $time);
            else begin
                errors = errors + 1;
                $display("[FAIL] %0s : expected %0s, got %0s  (t=%0t)",
                         label, state_name(expected), state_name(state_out), $time);
            end
        end
    endtask

    task check_bit;
        input value;
        input expected;
        input [255:0] label;
        begin
            checks = checks + 1;
            if (value === expected)
                $display("[PASS] %0s = %b", label, value);
            else begin
                errors = errors + 1;
                $display("[FAIL] %0s = %b (expected %b)", label, value, expected);
            end
        end
    endtask

    task tick;                     // advance N clock cycles
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
            #1;                    // settle after the edge
        end
    endtask

    // ------------------------------------------------ monitor state changes
    reg [3:0] prev_state;
    always @(posedge clk) begin
        if (state_out !== prev_state) begin
            $display(">>> TRANSITION: %0s -> %0s at t=%0t",
                     state_name(prev_state), state_name(state_out), $time);
            prev_state <= state_out;
        end
    end

    // ---------------------------------------------------------------- stimulus
    initial begin
        $dumpfile("sim/railway_crossing.vcd");
        $dumpvars(0, tb_railway_crossing_controller);

        prev_state         = 4'hF;
        train_approach     = 0;
        train_from_left    = 0;
        train_from_right   = 0;
        train_departed     = 0;
        obstacle_detected  = 0;
        emergency_override = 0;
        manual_reset       = 0;
        rst_n              = 0;

        $display("============================================");
        $display("SMART RAILWAY CROSSING SIMULATION");
        $display("============================================");
        $display("");

        //------------------------------------------------ TEST 1: reset
        $display("--- TEST 1: RESET ---");
        tick(2);
        rst_n = 1;
        tick(1);
        check_state(S_IDLE, "RESET -> IDLE");
        check_bit(barrier_up,      1'b1, "BARRIER UP in IDLE");
        check_bit(rail_signal_red, 1'b0, "RAIL SIGNAL GREEN in IDLE");
        check_bit(buzzer,          1'b0, "BUZZER OFF in IDLE");
        show_panel();

        //------------------------------- TEST 2: normal run, train from LEFT
        $display("--- TEST 2: NORMAL OPERATION, TRAIN FROM LEFT ---");
        train_approach  = 1;
        train_from_left = 1;
        tick(1);
        check_state(S_WARNING, "TRAIN APPROACH DETECTED");
        check_bit(rail_signal_red, 1'b1, "RAIL SIGNAL RED in WARNING");
        check_bit(warning_light,   1'b1, "WARNING LIGHT in WARNING");
        check_bit(buzzer,          1'b1, "BUZZER in WARNING");
        check_bit(barrier_up,      1'b1, "BARRIER STILL UP in WARNING");
        show_panel();
        checks = checks + 1;
        if (train_dir_out === 2'b01) $display("[PASS] TRAIN DIRECTION: LEFT -> RIGHT");
        else begin errors = errors + 1; $display("[FAIL] TRAIN DIRECTION wrong: %b", train_dir_out); end

        // warning timer (WARNING_TIME = 5)
        tick(4);
        check_state(S_WARNING, "WARNING TIMER STILL RUNNING");
        tick(1);
        check_state(S_CLOSING, "WARNING COMPLETE");
        check_bit(barrier_moving, 1'b1, "BARRIER MOVING in CLOSING");
        check_bit(barrier_down,   1'b1, "BARRIER DOWN cmd in CLOSING");
        show_panel();

        //------------------------------- TEST 3: obstacle during closing
        $display("--- TEST 3: OBSTACLE DURING CLOSING -> SAFETY HOLD ---");
        tick(1);
        obstacle_detected = 1;
        tick(1);
        check_state(S_SAFETY_HOLD, "OBSTACLE DETECTED");
        check_bit(barrier_moving, 1'b0, "BARRIER MOTOR STOPPED in SAFETY_HOLD");
        check_bit(rail_signal_red, 1'b1, "RAIL SIGNAL RED in SAFETY_HOLD");
        show_panel();

        tick(3);
        check_state(S_SAFETY_HOLD, "HOLD MAINTAINED WHILE OBSTACLE PRESENT");

        $display("--- TEST 4: OBSTACLE CLEARED -> RESUME CLOSING ---");
        obstacle_detected = 0;
        tick(1);
        check_state(S_CLOSING, "OBSTACLE CLEARED");
        show_panel();

        //------------------------------- TEST 5: closed + train passing
        $display("--- TEST 5: BARRIER CLOSED / TRAIN PASSING ---");
        tick(4);
        check_state(S_CLOSED, "BARRIER CLOSED");
        check_bit(barrier_down,   1'b1, "BARRIER DOWN in CLOSED");
        check_bit(barrier_moving, 1'b0, "BARRIER MOTOR OFF in CLOSED");
        show_panel();

        tick(1);
        check_state(S_TRAIN_PASSING, "TRAIN PASSING");
        show_panel();

        tick(4);
        check_state(S_TRAIN_PASSING, "TRAIN STILL ON CROSSING");

        //------------------------------- TEST 6: departure + opening
        $display("--- TEST 6: TRAIN DEPARTED -> OPENING -> IDLE ---");
        train_approach  = 0;
        train_from_left = 0;
        train_departed  = 1;
        tick(1);
        check_state(S_OPENING, "TRAIN DEPARTED");
        check_bit(barrier_up,     1'b1, "BARRIER UP cmd in OPENING");
        check_bit(barrier_moving, 1'b1, "BARRIER MOVING in OPENING");
        show_panel();

        train_departed = 0;
        tick(4);
        check_state(S_IDLE, "BARRIER OPEN");
        check_bit(rail_signal_red, 1'b0, "RAIL SIGNAL GREEN back in IDLE");
        show_panel();

        //------------------------------- TEST 7: train from RIGHT
        $display("--- TEST 7: TRAIN FROM RIGHT ---");
        train_approach   = 1;
        train_from_right = 1;
        tick(1);
        check_state(S_WARNING, "TRAIN APPROACH FROM RIGHT");
        checks = checks + 1;
        if (train_dir_out === 2'b10) $display("[PASS] TRAIN DIRECTION: RIGHT -> LEFT");
        else begin errors = errors + 1; $display("[FAIL] TRAIN DIRECTION wrong: %b", train_dir_out); end
        show_panel();

        tick(5);
        check_state(S_CLOSING, "WARNING COMPLETE (right-bound train)");

        //------------------------------- TEST 8: emergency override
        $display("--- TEST 8: EMERGENCY OVERRIDE (highest priority) ---");
        emergency_override = 1;
        tick(1);
        check_state(S_EMERGENCY, "EMERGENCY ASSERTED");
        check_bit(emergency_indicator, 1'b1, "EMERGENCY INDICATOR ON");
        check_bit(rail_signal_red,     1'b1, "RAIL SIGNAL RED in EMERGENCY");
        check_bit(barrier_up,          1'b1, "BARRIER RAISED (no unsafe closing)");
        show_panel();

        // emergency wins even over an obstacle and a fresh approach
        obstacle_detected = 1;
        tick(2);
        check_state(S_EMERGENCY, "EMERGENCY HOLDS OVER OBSTACLE");
        obstacle_detected = 0;

        // releasing the switch alone must NOT clear the emergency
        emergency_override = 0;
        tick(2);
        check_state(S_EMERGENCY, "EMERGENCY LATCHED UNTIL OPERATOR ACK");

        $display("--- TEST 9: RECOVERY VIA MANUAL RESET ---");
        manual_reset = 1;
        tick(1);
        manual_reset = 0;
        check_state(S_OPENING, "OPERATOR ACK -> BARRIER RAISED");
        show_panel();

        train_approach   = 0;
        train_from_right = 0;
        tick(4);
        check_state(S_IDLE, "RECOVERED TO IDLE");
        show_panel();

        //------------------------------- TEST 10: async reset mid-sequence
        $display("--- TEST 10: ASYNCHRONOUS RESET DURING OPERATION ---");
        train_approach = 1;
        tick(3);
        check_state(S_WARNING, "MID-SEQUENCE (WARNING)");
        rst_n = 0;
        #2;
        check_state(S_IDLE, "ASYNC RESET FORCES IDLE");
        rst_n = 1;
        train_approach = 0;
        tick(2);
        show_panel();

        //------------------------------------------------ summary
        $display("============================================");
        $display("CHECKS RUN : %0d", checks);
        $display("FAILURES   : %0d", errors);
        if (errors == 0) $display("TEST RESULT: PASS");
        else             $display("TEST RESULT: FAIL");
        $display("============================================");
        $finish;
    end

endmodule
