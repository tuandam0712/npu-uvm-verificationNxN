`default_nettype none
module controller_formal;

    localparam int N = 8;
    localparam int DRAIN_MARGIN = 10;
    localparam int CNT_W = $clog2(3*N + DRAIN_MARGIN + 4);

    logic clk;
    logic rst_n;
    logic start;

    logic valid_in;
    logic clear;
    logic done;
    logic past_valid;
    logic [2:0] formal_state;
    logic [CNT_W-1:0] formal_cycle_cnt;
    logic [CNT_W-1:0] formal_drain_cnt;

    localparam logic [2:0] IDLE_STATE        = 3'd0;
    localparam logic [2:0] CLEAR_STATE       = 3'd1;
    localparam logic [2:0] COMPUTE_STATE     = 3'd2;
    localparam logic [2:0] WAIT_DRAIN_STATE = 3'd3;
    localparam logic [2:0] DONE_STATE        = 3'd4;

    localparam int COMPUTE_CYCLES = N;
    localparam int DRAIN_CYCLES   = 2*N + DRAIN_MARGIN;

    sa_controller_NxN #(
        .N(N),
        .DRAIN_MARGIN(DRAIN_MARGIN),
        .CNT_W(CNT_W)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .formal_state     (formal_state),
        .formal_cycle_cnt (formal_cycle_cnt),
        .formal_drain_cnt (formal_drain_cnt),
        .valid_in (valid_in),
        .clear    (clear),
        .done     (done)
    );
    initial past_valid = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
    end
    `ifdef PROVE_RESET
    always @(posedge clk) begin
        if(!rst_n) begin
            A_CTRL_RST_002:
                assert(formal_state == IDLE_STATE);
            A_CTRL_RST_003:
                assert(clear == 1'b0 && valid_in == 1'b0 && done == 1'b0);
        end
    end
    `endif
    `ifdef PROVE_START
    always @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n) &&
            $past(formal_state) == IDLE_STATE && $past(start)) begin
            A_CTRL_START_002_CLR_001:
                assert (formal_state == CLEAR_STATE);
        end
        if (past_valid && rst_n && $past(rst_n) && $past(formal_state) == IDLE_STATE && !$past(start)
        ) begin
            A_CTRL_IDLE_002:
                assert (formal_state == IDLE_STATE);
        end
    end
    `endif
    `ifdef PROVE_PHASE
    always @(posedge clk) begin
        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == CLEAR_STATE
        ) begin
            A_CTRL_CLR_003_004:
                assert (
                    formal_state     == COMPUTE_STATE &&
                    formal_cycle_cnt == '0
                );
        end

        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == COMPUTE_STATE &&
            $past(formal_cycle_cnt) < COMPUTE_CYCLES-1
        ) begin
            A_CTRL_COMP_002_CONTINUE:
                assert (
                    formal_state == COMPUTE_STATE &&
                    formal_cycle_cnt ==
                        $past(formal_cycle_cnt) + 1'b1
                );
        end

        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == COMPUTE_STATE &&
            $past(formal_cycle_cnt) >= COMPUTE_CYCLES-1
        ) begin
            A_CTRL_COMP_002_003_EXIT:
                assert (
                    formal_state     == WAIT_DRAIN_STATE &&
                    formal_drain_cnt == '0
                );
        end

        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == WAIT_DRAIN_STATE &&
            $past(formal_drain_cnt) < DRAIN_CYCLES-1
        ) begin
            A_CTRL_DRAIN_002_CONTINUE:
                assert (
                    formal_state == WAIT_DRAIN_STATE &&
                    formal_drain_cnt ==
                        $past(formal_drain_cnt) + 1'b1
                );
        end

        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == WAIT_DRAIN_STATE &&
            $past(formal_drain_cnt) >= DRAIN_CYCLES-1
        ) begin
            A_CTRL_DRAIN_002_003_EXIT:
                assert (
                    formal_state == DONE_STATE
                );
        end

        if (
            past_valid &&
            rst_n &&
            $past(rst_n) &&
            $past(formal_state) == DONE_STATE
        ) begin
            A_CTRL_DONE_002_003:
                assert (
                    formal_state == IDLE_STATE
                );
        end
    end
    `endif
    `ifdef PROVE_START_BUSY
    always @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n) && $past(start)) begin

            if ($past(formal_state) == CLEAR_STATE) begin
                A_CTRL_START_003_CLEAR_IGNORED:
                    assert(formal_state == COMPUTE_STATE);
            end

            if ($past(formal_state) == COMPUTE_STATE &&
                $past(formal_cycle_cnt) < COMPUTE_CYCLES-1) begin
                A_CTRL_START_003_COMPUTE_CONTINUE:
                    assert(
                        formal_state == COMPUTE_STATE &&
                        formal_cycle_cnt == $past(formal_cycle_cnt) + 1'b1
                    );
            end

            if ($past(formal_state) == COMPUTE_STATE &&
                $past(formal_cycle_cnt) >= COMPUTE_CYCLES-1) begin
                A_CTRL_START_003_COMPUTE_EXIT:
                    assert(formal_state == WAIT_DRAIN_STATE);
            end

            if ($past(formal_state) == WAIT_DRAIN_STATE &&
                $past(formal_drain_cnt) < DRAIN_CYCLES-1) begin
                A_CTRL_START_003_DRAIN_CONTINUE:
                    assert(
                        formal_state == WAIT_DRAIN_STATE &&
                        formal_drain_cnt == $past(formal_drain_cnt) + 1'b1
                    );
            end

            if ($past(formal_state) == WAIT_DRAIN_STATE &&
                $past(formal_drain_cnt) >= DRAIN_CYCLES-1) begin
                A_CTRL_START_003_DRAIN_EXIT:
                    assert(formal_state == DONE_STATE);
            end

            if ($past(formal_state) == DONE_STATE) begin
                A_CTRL_START_003_DONE_IGNORED:
                    assert(formal_state == IDLE_STATE);
            end
        end
    end
    `endif
    `ifdef PROVE_OUTPUT
    always @(posedge clk) begin
        if (rst_n) begin
            if (formal_state == IDLE_STATE) begin
                A_CTRL_IDLE_001:
                    assert(!clear && !valid_in && !done);
            end

            if (formal_state == CLEAR_STATE) begin
                A_CTRL_CLR_002:
                    assert(clear && !valid_in && !done);
            end

            if (formal_state == COMPUTE_STATE) begin
                A_CTRL_COMP_001:
                    assert(!clear && valid_in && !done);
            end

            if (formal_state == WAIT_DRAIN_STATE) begin
                A_CTRL_DRAIN_001:
                    assert(!clear && !valid_in && !done);
            end

            if (formal_state == DONE_STATE) begin
                A_CTRL_DONE_001:
                    assert(!clear && !valid_in && done);
            end
        end
    end
    `endif
endmodule
`default_nettype wire
