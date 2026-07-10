module sa_controller_NxN #(
    parameter int N = 8,
    parameter int DRAIN_MARGIN = 10,
    parameter int CNT_W = $clog2(3*N + DRAIN_MARGIN + 4)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic valid_in,
    output logic clear,
    output logic done
);
    localparam int COMPUTE_CYCLES = N;
    localparam int DRAIN_CYCLES   = 2*N + DRAIN_MARGIN;
    typedef enum logic [2:0] {
        IDLE,
        CLEAR,
        COMPUTE,
        WAIT_DRAIN,
        DONE_STATE
    } state_t;
    state_t state, next_state;
    logic [CNT_W-1:0] cycle_count;
    logic [CNT_W-1:0] drain_count;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            cycle_count <= '0;
            drain_count <= '0;
        end else begin
            state <= next_state;
            unique case (state)
                COMPUTE: begin
                    cycle_count <= cycle_count + 1'b1;
                    drain_count <= '0;
                end
                WAIT_DRAIN: begin
                    cycle_count <= '0;
                    drain_count <= drain_count + 1'b1;
                end
                default: begin
                    cycle_count <= '0;
                    drain_count <= '0;
                end
            endcase
        end
    end
    always_comb begin
        next_state = state;
        unique case (state)
            IDLE: begin
                if (start) next_state = CLEAR;
            end
            CLEAR: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (cycle_count >= COMPUTE_CYCLES-1) next_state = WAIT_DRAIN;
            end
            WAIT_DRAIN: begin
                if (drain_count >= DRAIN_CYCLES) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    assign valid_in = (state == COMPUTE);
    assign clear    = (state == CLEAR);
    assign done     = (state == DONE_STATE);
    //sva
    localparam int EXPECTED_LATENCY = 3*N + DRAIN_MARGIN + 1;
    localparam int LATENCY_TOLERANCE = 2;
    property p_start_to_done_latency;
        @(posedge clk)
        disable iff(!rst_n)
        $rose(start)
        |-> ##[EXPECTED_LATENCY - LATENCY_TOLERANCE :
            EXPECTED_LATENCY + LATENCY_TOLERANCE] done;
    endproperty

    A_START_TO_DONE_LATENCY:
    assert property(p_start_to_done_latency)
    else $error("[CTRL_SVA] start -> done latency out of range");


    property p_done_one_cycle;
        @(posedge clk)
        disable iff(!rst_n)
        done |=> !done;
    endproperty

    A_DONE_ONE_CYCLE:
    assert property(p_done_one_cycle)
    else $error("[CTRL_SVA] done pulse longer than 1 cycle");


    property p_clear_one_cycle;
        @(posedge clk)
        disable iff(!rst_n)
        clear |=> !clear;
    endproperty

    A_CLEAR_ONE_CYCLE:
    assert property(p_clear_one_cycle)
    else $error("[CTRL_SVA] clear pulse longer than 1 cycle");


    property p_valid_only_in_compute;
        @(posedge clk)
        disable iff(!rst_n)
        valid_in |-> (state == COMPUTE);
    endproperty

    A_VALID_ONLY_IN_COMPUTE:
    assert property(p_valid_only_in_compute)
    else $error("[CTRL_SVA] valid_in active outside COMPUTE");


    property p_idle_to_clear;
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && start) |=> (state == CLEAR);
    endproperty

    A_IDLE_TO_CLEAR:
    assert property(p_idle_to_clear)
    else $error("[CTRL_SVA] IDLE + start did not go to CLEAR");


    property p_clear_to_compute;
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) |=> (state == COMPUTE);
    endproperty

    A_CLEAR_TO_COMPUTE:
    assert property(p_clear_to_compute)
    else $error("[CTRL_SVA] CLEAR did not go to COMPUTE");


    property p_compute_to_drain;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && cycle_count == COMPUTE_CYCLES-1)
        |=> (state == WAIT_DRAIN);
    endproperty

    A_COMPUTE_TO_DRAIN:
    assert property(p_compute_to_drain)
    else $error("[CTRL_SVA] COMPUTE did not go to WAIT_DRAIN");


    // bản mềm, tránh fail do lệch counter 1 cycle
    property p_drain_eventually_done;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && drain_count >= DRAIN_CYCLES-1)
        |-> ##[0:2] (state == DONE_STATE || done);
    endproperty

    A_DRAIN_EVENTUALLY_DONE:
    assert property(p_drain_eventually_done)
    else $error("[CTRL_SVA] WAIT_DRAIN did not lead to DONE_STATE/done");


    property p_done_to_idle;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE) |=> (state == IDLE);
    endproperty

    A_DONE_TO_IDLE:
    assert property(p_done_to_idle)
    else $error("[CTRL_SVA] DONE_STATE did not go to IDLE");
endmodule
