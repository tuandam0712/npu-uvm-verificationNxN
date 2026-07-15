`timescale 1ns/1ps

module tb_controller_directed;
    localparam int N            = 4;
    localparam int DRAIN_MARGIN = 3;
    localparam int DRAIN_CYCLES = 2*N + DRAIN_MARGIN;
    localparam int TIMEOUT      = 200;

    localparam logic [2:0] IDLE       = 3'd0;
    localparam logic [2:0] CLEAR      = 3'd1;
    localparam logic [2:0] COMPUTE    = 3'd2;
    localparam logic [2:0] WAIT_DRAIN = 3'd3;
    localparam logic [2:0] DONE_STATE = 3'd4;

    logic clk;
    logic rst_n;
    logic start;
    logic valid_in;
    logic clear;
    logic done;

    int checks;
    int errors;

    sa_controller_NxN #(
        .N(N),
        .DRAIN_MARGIN(DRAIN_MARGIN)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .valid_in(valid_in),
        .clear(clear),
        .done(done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic sample_edge;
        @(posedge clk);
        #1ps;
    endtask

    task automatic check(input bit condition, input string message);
        checks++;
        if (!condition) begin
            errors++;
            $error("[TB_CTRL] %s time=%0t state=%0d start=%0b clear=%0b valid=%0b done=%0b cycle=%0d drain=%0d",
                message, $time, dut.state, start, clear, valid_in, done,
                dut.cycle_count, dut.drain_count);
        end
    endtask

    task automatic check_state(input logic [2:0] expected, input string test_name);
        check(dut.state === expected,
              $sformatf("%s: expected state=%0d got=%0d", test_name, expected, dut.state));
    endtask

    task automatic check_outputs(
        input logic exp_clear,
        input logic exp_valid,
        input logic exp_done,
        input string test_name
    );
        check({clear, valid_in, done} === {exp_clear, exp_valid, exp_done},
              $sformatf("%s: expected outputs=%0b%0b%0b got=%0b%0b%0b",
                        test_name, exp_clear, exp_valid, exp_done,
                        clear, valid_in, done));
    endtask

    task automatic apply_reset;
        start = 1'b0;
        rst_n = 1'b0;
        #1;
        check_state(IDLE, "reset state");
        check_outputs(1'b0, 1'b0, 1'b0, "reset outputs");
        repeat (2) sample_edge();
        rst_n = 1'b1;
        sample_edge();
        check_state(IDLE, "reset release");
    endtask

    task automatic wait_state(input logic [2:0] target, input string test_name);
        int waited;
        waited = 0;
        while (dut.state !== target && waited < TIMEOUT) begin
            sample_edge();
            waited++;
        end
        check(dut.state === target,
              $sformatf("%s: timeout waiting state=%0d", test_name, target));
    endtask

    task automatic accept_start;
        check_state(IDLE, "accept_start precondition");
        start = 1'b1;
        sample_edge();
        start = 1'b0;
        check_state(CLEAR, "IDLE + start -> CLEAR");
        check_outputs(1'b1, 1'b0, 1'b0, "CLEAR decode");
    endtask

    task automatic finish_current_operation;
        wait_state(DONE_STATE, "finish operation");
        check_outputs(1'b0, 1'b0, 1'b1, "DONE decode");
        sample_edge();
        check_state(IDLE, "DONE -> IDLE");
    endtask

    task automatic test_async_reset_between_edges;
        $display("[TEST] async reset between clock edges");
        apply_reset();
        accept_start();
        sample_edge();
        check_state(COMPUTE, "entered COMPUTE before async reset");
        #2;
        rst_n = 1'b0;
        #1;
        check_state(IDLE, "async reset immediate state");
        check_outputs(1'b0, 1'b0, 1'b0, "async reset immediate outputs");
        rst_n = 1'b1;
        sample_edge();
    endtask

    task automatic test_reset_in_state(input logic [2:0] target, input string name);
        $display("[TEST] reset in %s", name);
        apply_reset();
        accept_start();
        wait_state(target, $sformatf("reach %s", name));
        #2;
        rst_n = 1'b0;
        #1;
        check_state(IDLE, $sformatf("reset from %s", name));
        check_outputs(1'b0, 1'b0, 1'b0, $sformatf("reset outputs from %s", name));
        rst_n = 1'b1;
        sample_edge();
    endtask


    task automatic test_reset_priority_with_start;
        $display("[TEST] reset priority over start");
        apply_reset();
        accept_start();
        wait_state(COMPUTE, "reach COMPUTE before reset priority test");
        start = 1'b1;
        #2;
        rst_n = 1'b0;
        #1;
        check_state(IDLE, "reset wins over start/current operation");
        check_outputs(1'b0, 1'b0, 1'b0, "reset priority outputs");
        repeat (2) sample_edge();
        check_state(IDLE, "start not accepted while reset active");
        start = 1'b0;
        rst_n = 1'b1;
        sample_edge();
    endtask

    task automatic test_start_at_idle;
        $display("[TEST] start at IDLE");
        apply_reset();
        accept_start();
        finish_current_operation();
    endtask

    task automatic pulse_start_one_cycle;
        start = 1'b1;
        sample_edge();
        start = 1'b0;
    endtask

    task automatic test_busy_start_ignored;
        int prev_count;
        $display("[TEST] start pulse in busy phases");
        apply_reset();

        accept_start();
        start = 1'b1;
        sample_edge();
        start = 1'b0;
        check_state(COMPUTE, "start in CLEAR ignored");

        prev_count = dut.cycle_count;
        start = 1'b1;
        sample_edge();
        start = 1'b0;
        check_state(COMPUTE, "start in COMPUTE ignored");
        check(dut.cycle_count == prev_count + 1,
              "COMPUTE counter progressed despite start");

        wait_state(WAIT_DRAIN, "reach WAIT_DRAIN");
        prev_count = dut.drain_count;
        start = 1'b1;
        sample_edge();
        start = 1'b0;
        check_state(WAIT_DRAIN, "start in WAIT_DRAIN ignored");
        check(dut.drain_count == prev_count + 1,
              "drain counter progressed despite start");

        wait_state(DONE_STATE, "reach DONE for busy-start test");
        start = 1'b1;
        sample_edge();
        start = 1'b0;
        check_state(IDLE, "start in DONE ignored for current operation");
        sample_edge();
        check_state(IDLE, "DONE start pulse not queued");
    endtask

    task automatic test_exact_phase_durations;
        int count;
        $display("[TEST] exact CLEAR/COMPUTE/DRAIN/DONE durations");
        apply_reset();
        accept_start();

        sample_edge();
        check_state(COMPUTE, "CLEAR exactly one cycle");

        count = 0;
        while (dut.state == COMPUTE && count < TIMEOUT) begin
            check_outputs(1'b0, 1'b1, 1'b0, "COMPUTE decode");
            count++;
            sample_edge();
        end
        check(count == N,
              $sformatf("COMPUTE duration expected=%0d got=%0d", N, count));
        check_state(WAIT_DRAIN, "COMPUTE terminal transition");

        count = 0;
        while (dut.state == WAIT_DRAIN && count < TIMEOUT) begin
            check_outputs(1'b0, 1'b0, 1'b0, "WAIT_DRAIN decode");
            count++;
            sample_edge();
        end
        check(count == DRAIN_CYCLES,
              $sformatf("WAIT_DRAIN duration expected=%0d got=%0d",
                        DRAIN_CYCLES, count));
        check_state(DONE_STATE, "DRAIN terminal transition");
        check_outputs(1'b0, 1'b0, 1'b1, "DONE decode");

        sample_edge();
        check_state(IDLE, "DONE exactly one cycle");
    endtask

    task automatic test_busy_pulse_not_queued;
        $display("[TEST] busy pulse not queued");
        apply_reset();
        accept_start();
        wait_state(COMPUTE, "reach COMPUTE");
        pulse_start_one_cycle();
        finish_current_operation();
        sample_edge();
        check_state(IDLE, "no pending request after busy pulse");
    endtask

    task automatic test_held_start_reaccepted;
        $display("[TEST] held-high start reaccepted");
        apply_reset();
        accept_start();
        wait_state(WAIT_DRAIN, "reach WAIT_DRAIN before holding start");
        start = 1'b1;
        wait_state(DONE_STATE, "held start through DONE");
        sample_edge();
        check_state(IDLE, "held start returns through IDLE");
        sample_edge();
        check_state(CLEAR, "held start accepted again");
        start = 1'b0;
        finish_current_operation();
    endtask

    task automatic test_back_to_back_operations;
        $display("[TEST] two back-to-back operations");
        apply_reset();
        accept_start();
        wait_state(DONE_STATE, "first operation DONE");
        start = 1'b1;
        sample_edge();
        check_state(IDLE, "inter-operation IDLE cycle");
        sample_edge();
        check_state(CLEAR, "second operation accepted");
        start = 1'b0;
        finish_current_operation();
    endtask

    initial begin
        rst_n  = 1'b1;
        start  = 1'b0;
        checks = 0;
        errors = 0;

        test_async_reset_between_edges();
        test_reset_in_state(CLEAR,      "CLEAR");
        test_reset_in_state(COMPUTE,    "COMPUTE");
        test_reset_in_state(WAIT_DRAIN, "WAIT_DRAIN");
        test_reset_in_state(DONE_STATE, "DONE_STATE");
        test_reset_priority_with_start();
        test_start_at_idle();
        test_busy_start_ignored();
        test_exact_phase_durations();
        test_busy_pulse_not_queued();
        test_held_start_reaccepted();
        test_back_to_back_operations();

        if (errors == 0) begin
            $display("[TB_CTRL] PASS checks=%0d errors=%0d", checks, errors);
        end else begin
            $fatal(1, "[TB_CTRL] FAIL checks=%0d errors=%0d", checks, errors);
        end
        $finish;
    end

endmodule
