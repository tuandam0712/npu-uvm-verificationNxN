module sa_controller_NxN #(
    parameter int N = 8,
    parameter int DRAIN_MARGIN = 10,
    parameter int CNT_W = $clog2(3*N + DRAIN_MARGIN + 4)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
`ifdef SA_CTRL_FORMAL_SBY
    output logic [2:0] formal_state,
    output logic [CNT_W-1:0] formal_cycle_cnt,
    output logic [CNT_W-1:0] formal_drain_cnt,
`endif
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
                if (cycle_count >= COMPUTE_CYCLES - 1) next_state = WAIT_DRAIN;
            end
            WAIT_DRAIN: begin
                if (drain_count >= DRAIN_CYCLES - 1) next_state = DONE_STATE;
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
`ifdef SA_CTRL_FORMAL_SBY
    assign formal_state = state;
    assign formal_cycle_cnt = cycle_count;
    assign formal_drain_cnt = drain_count;
`endif
    `ifndef SA_CTRL_FORMAL_SBY
    property p_ctrl_rst_002;
        @(posedge clk)
        (!rst_n) |-> (state == IDLE);
    endproperty
    A_CTRL_RST_002:
    assert property(p_ctrl_rst_002)
    else $error("[CTRL_SVA] RST mismatch state=%0d time=%0t rst_n=%0b",
        state, $time,
        $sampled(rst_n)
    );
    C_CTRL_RST_002:
    cover property(
        @(posedge clk)
        (!rst_n) 
    );
    property p_ctrl_rst_003;
        @(posedge clk)
        (!rst_n) |-> (!clear && !valid_in && !done);
    endproperty
    A_CTRL_RST_003:
    assert property(p_ctrl_rst_003)
    else $error("[CTRL_SVA] RST mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_RST_003:
    cover property(
        @(posedge clk)
        (!rst_n) 
    );
    property p_ctrl_rst_004;
        @(posedge clk)
        (!rst_n && start) |-> (state == IDLE && !clear && !valid_in && !done);
    endproperty
    A_CTRL_RST_004:
    assert property(p_ctrl_rst_004)
    else $error("[CTRL_SVA] RST mismatch state=%0d time=%0t rst_n=%0b start=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_RST_004:
    cover property(
        @(posedge clk)
        (!rst_n && start) 
    );
    property p_ctrl_start_002;
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && start) |=> (state == CLEAR);
    endproperty//ctrl_clr002
    A_CTRL_START_002:
    assert property(p_ctrl_start_002)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_START_002:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && start) 
    );
    property p_ctrl_start_003_clear_ignored;
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR && start) |=> (state == COMPUTE);
    endproperty
    A_CTRL_START_003_CLEAR_IGNORED:
    assert property(p_ctrl_start_003_clear_ignored)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_START_003_CLEAR_IGNORED:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR && start) 
    );
    property p_ctrl_start_003_compute_continue;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && start && cycle_count < COMPUTE_CYCLES-1) |=> (state == COMPUTE);
    endproperty
    A_CTRL_START_003_COMPUTE_CONTINUE:
    assert property(p_ctrl_start_003_compute_continue)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b cycle_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(start),
        $sampled(cycle_count)
    );
    C_CTRL_START_003_COMPUTE_CONTINUE:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && start && cycle_count < COMPUTE_CYCLES-1) 
    );
    property p_ctrl_start_003_compute_exit;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && start && cycle_count >= COMPUTE_CYCLES-1) |=> (state == WAIT_DRAIN); 
    endproperty
    A_CTRL_START_003_COMPUTE_EXIT:
    assert property(p_ctrl_start_003_compute_exit)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b cycle_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(start),
        $sampled(cycle_count)
    );
    C_CTRL_START_003_COMPUTE_EXIT:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && start && cycle_count >= COMPUTE_CYCLES-1) 
    );
    property p_ctrl_start_003_drain_continue;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && start && drain_count < DRAIN_CYCLES-1) |=> (state == WAIT_DRAIN);
    endproperty
    A_CTRL_START_003_DRAIN_CONTINUE:
    assert property(p_ctrl_start_003_drain_continue)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b drain_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(start),
        $sampled(drain_count)
    );
    C_CTRL_START_003_DRAIN_CONTINUE:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && start && drain_count < DRAIN_CYCLES-1) 
    );
    property p_ctrl_start_003_drain_exit;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && start && drain_count >= DRAIN_CYCLES-1) |=> (state == DONE_STATE);
    endproperty
    A_CTRL_START_003_DRAIN_EXIT:
    assert property(p_ctrl_start_003_drain_exit)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b drain_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(start),
        $sampled(drain_count)
    );
    C_CTRL_START_003_DRAIN_EXIT:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && start && drain_count >= DRAIN_CYCLES-1) 
    );
    property p_ctrl_start_003_done_ignored;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && start) |=> (state == IDLE);
    endproperty
    A_CTRL_START_003_DONE_IGNORED:
    assert property(p_ctrl_start_003_done_ignored)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_START_003_DONE_IGNORED:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && start) 
    );
    property p_ctrl_start_004_reaccept_held_start;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && start) ##1 (state == IDLE && start) |=> (state == CLEAR);
    endproperty
    A_CTRL_START_004_REACCEPT_HELD_START:
    assert property(p_ctrl_start_004_reaccept_held_start)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_START_004_REACCEPT_HELD_START:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && start) ##1 (state == IDLE && start) 
    );
    property p_ctrl_start_004_no_pending_req;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && !start) |=> (state == IDLE);
    endproperty
    A_CTRL_START_004_NO_PENDING_REQ:
    assert property(p_ctrl_start_004_no_pending_req)
    else $error("[CTRL_SVA] START mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_START_004_NO_PENDING_REQ:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE && !start) 
    );
    property p_ctrl_clr_002_output;
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) |-> (clear == 1'b1 && valid_in == 1'b0 && done == 1'b0);
    endproperty
    A_CTRL_CLR_002_OUTPUT:
    assert property(p_ctrl_clr_002_output)
    else $error("[CTRL_SVA] CLR mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_CLR_002_OUTPUT:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) 
    );
    property p_ctrl_clr_003;
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) |=> (state == COMPUTE);
    endproperty//ctrl_clr_003=clr_req003+cllr_req_004
    A_CTRL_CLR_003:
    assert property(p_ctrl_clr_003)
    else $error("[CTRL_SVA] CLR mismatch state=%0d time=%0t rst_n=%0b clear=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear)
    );
    C_CTRL_CLR_003:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) 
    ); 
    property p_ctrl_comp_001;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE) |-> (clear == 1'b0 && valid_in == 1'b1 && done == 1'b0);
    endproperty
    A_CTRL_COMP_001:
    assert property(p_ctrl_comp_001)
    else $error("[CTRL_SVA] COMPUTE mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_COMP_001:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE) 
    );
    property p_ctrl_comp_002_entry_cnt_0;
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) |=> (state == COMPUTE && cycle_count == 0);
    endproperty
    A_CTRL_COMP_002_ENTRY_CNT_0:
    assert property(p_ctrl_comp_002_entry_cnt_0)
    else $error("[CTRL_SVA] COMPUTE mismatch state=%0d time=%0t rst_n=%0b clear=%0b cycle_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(cycle_count)
    );
    C_CTRL_COMP_002_ENTRY_CNT_0:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == CLEAR) 
    );
    property p_ctrl_comp_002_continue;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && cycle_count < COMPUTE_CYCLES-1) |=> (state == COMPUTE && cycle_count == $past(cycle_count) + 1);
    endproperty
    A_CTRL_COMP_002_CONTINUE:
    assert property(p_ctrl_comp_002_continue)
    else $error("[CTRL_SVA] COMPUTE mismatch state=%0d time=%0t rst_n=%0b clear=%0b cycle_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(cycle_count)
    );
    C_CTRL_COMP_002_CONTINUE:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && cycle_count < COMPUTE_CYCLES-1) 
    );
    property p_ctrl_comp_002_exit;
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && cycle_count >= COMPUTE_CYCLES-1) |=> (state == WAIT_DRAIN && drain_count == 0);
    endproperty
    A_CTRL_COMP_002_EXIT:
    assert property(p_ctrl_comp_002_exit)
    else $error("[CTRL_SVA] COMPUTE mismatch state=%0d time=%0t rst_n=%0b clear=%0b cycle_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(cycle_count)
    );
    C_CTRL_COMP_002_EXIT:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == COMPUTE && cycle_count >= COMPUTE_CYCLES-1)  
    );//ctrl_comp_003 + ctrl_wait_drain_002_entry
    property p_ctrl_drain_001;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN) |-> (clear == 1'b0 && valid_in == 1'b0 && done == 1'b0);
    endproperty
    A_CTRL_DRAIN_001:
    assert property(p_ctrl_drain_001)
    else $error("[CTRL_SVA] WAIT_DRAIN mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_DRAIN_001:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN) 
    );
    property p_ctrl_drain_002_continue;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && drain_count < DRAIN_CYCLES-1) |=> (state == WAIT_DRAIN && drain_count == $past(drain_count) + 1);
    endproperty
    A_CTRL_DRAIN_002_CONTINUE:
    assert property(p_ctrl_drain_002_continue)
    else $error("[CTRL_SVA] WAIT_DRAIN mismatch state=%0d time=%0t rst_n=%0b clear=%0b drain_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(drain_count)
    );
    C_CTRL_DRAIN_002_CONTINUE:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && drain_count < DRAIN_CYCLES-1) 
    );
    property p_ctrl_drain_002_exit;
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && drain_count >= DRAIN_CYCLES-1) |=> (state == DONE_STATE && cycle_count == 0);
    endproperty//ctrl_wait_drain003
    A_CTRL_DRAIN_002_EXIT:
    assert property(p_ctrl_drain_002_exit)
    else $error("[CTRL_SVA] WAIT_DRAIN mismatch state=%0d time=%0t rst_n=%0b clear=%0b drain_count=%0d",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(drain_count)
    );
    C_CTRL_DRAIN_002_EXIT:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == WAIT_DRAIN && drain_count >= DRAIN_CYCLES-1) 
    );
    property p_ctrl_done_001;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE) |-> (clear == 1'b0 && valid_in == 1'b0 && done == 1'b1);
    endproperty
    A_CTRL_DONE_001:
    assert property(p_ctrl_done_001)
    else $error("[CTRL_SVA] DONE_STATE mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_DONE_001:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE) 
    );
    property p_ctrl_done_002;
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE) |=> (state == IDLE);
    endproperty//ctrl_done003
    A_CTRL_DONE_002:
    assert property(p_ctrl_done_002)
    else $error("[CTRL_SVA] DONE_STATE mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_DONE_002:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == DONE_STATE) 
    );
    property p_ctrl_idle_001;
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE) |-> (clear == 1'b0 && valid_in == 1'b0 && done == 1'b0);
    endproperty
    A_CTRL_IDLE_001:
    assert property(p_ctrl_idle_001)
    else $error("[CTRL_SVA] IDLE mismatch state=%0d time=%0t rst_n=%0b clear=%0b valid_in=%0b done=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid_in),
        $sampled(done)
    );
    C_CTRL_IDLE_001:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE) 
    );
    property p_ctrl_idle_002;
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && !start) |=> (state == IDLE);
    endproperty
    A_CTRL_IDLE_002:
    assert property(p_ctrl_idle_002)
    else $error("[CTRL_SVA] IDLE mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_IDLE_002:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && !start) 
    );
    localparam int EXP_LAT = COMPUTE_CYCLES + DRAIN_CYCLES + 2;
    property p_ctrl_latency;
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && start) |-> ##EXP_LAT (state == DONE_STATE && done == 1'b1);
    endproperty
    A_CTRL_LATENCY:
    assert property(p_ctrl_latency)
    else $error("[CTRL_SVA] latency mismatch state=%0d time=%0t rst_n=%0b start=%0b",
        state, $time,
        $sampled(rst_n),
        $sampled(start)
    );
    C_CTRL_LATENCY:
    cover property(
        @(posedge clk)
        disable iff(!rst_n)
        (state == IDLE && start) 
    );

    `endif
endmodule
