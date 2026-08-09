module systolic_arr_NxN #(
    parameter int N = 8,
    parameter int width = 8,
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic clear,
`ifdef SARR_FORMAL_SBY
    input  logic signed [N*width-1:0] formal_a_in_flat,
    input  logic signed [N*width-1:0] formal_b_in_flat,
    output logic signed [N*N*width-1:0] formal_a_wire_flat,
    output logic signed [N*N*width-1:0] formal_b_wire_flat,
    output logic signed [N*N*width-1:0] formal_a_delay_flat,
    output logic signed [N*N*width-1:0] formal_b_delay_flat,
    output logic [N*N-1:0] formal_pe_valid_flat,
    output logic signed [N*N*ACC_WIDTH-1:0] formal_c_flat
`else
    input  logic signed [width-1:0] a_in [N-1:0],
    input  logic signed [width-1:0] b_in [N-1:0],
    output logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0]
`endif
);
`ifdef SARR_FORMAL_SBY
    logic signed [width-1:0] a_in [N-1:0];
    logic signed [width-1:0] b_in [N-1:0];
    logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0];
`endif
    logic signed [width-1:0] a_wire [N-1:0][N-1:0];
    logic signed [width-1:0] b_wire [N-1:0][N-1:0];
    logic signed [width-1:0] a_delay [N-1:0][N-1:0];
    logic signed [width-1:0] b_delay [N-1:0][N-1:0];
    logic pe_valid [N-1:0][N-1:0];

`ifdef SARR_FORMAL_SBY
    generate
        for (genvar formal_i = 0; formal_i < N; formal_i++) begin : formal_flat_row
            assign a_in[formal_i] = formal_a_in_flat[formal_i*width +: width];
            assign b_in[formal_i] = formal_b_in_flat[formal_i*width +: width];
            for (genvar formal_j = 0; formal_j < N; formal_j++) begin : formal_flat_col
                localparam int FORMAL_ELEM = formal_i*N + formal_j;
                assign formal_a_wire_flat[FORMAL_ELEM*width +: width] = a_wire[formal_i][formal_j];
                assign formal_b_wire_flat[FORMAL_ELEM*width +: width] = b_wire[formal_i][formal_j];
                assign formal_a_delay_flat[FORMAL_ELEM*width +: width] = a_delay[formal_i][formal_j];
                assign formal_b_delay_flat[FORMAL_ELEM*width +: width] = b_delay[formal_i][formal_j];
                assign formal_pe_valid_flat[FORMAL_ELEM] = pe_valid[formal_i][formal_j];
                assign formal_c_flat[FORMAL_ELEM*ACC_WIDTH +: ACC_WIDTH] = c[formal_i][formal_j];
            end
        end
    endgenerate
`endif
    genvar i, j, k;
    generate
        for (i = 0; i < N; i++) begin : a_skew_gen
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)      a_delay[i][0] <= '0;
                else if (clear) a_delay[i][0] <= '0;
                else            a_delay[i][0] <= a_in[i];
            end
            for (k = 1; k < N; k++) begin : a_chain
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      a_delay[i][k] <= '0;
                    else if (clear) a_delay[i][k] <= '0;
                    else            a_delay[i][k] <= a_delay[i][k-1];
                end
            end
            if (i == 0) begin : a_row0
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      a_wire[0][0] <= '0;
                    else if (clear) a_wire[0][0] <= '0;
                    else            a_wire[0][0] <= a_in[0];
                end
            end else begin : a_row_delay
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      a_wire[i][0] <= '0;
                    else if (clear) a_wire[i][0] <= '0;
                    else            a_wire[i][0] <= a_delay[i][i-1];
                end
            end
        end
    endgenerate
    generate
        for (j = 0; j < N; j++) begin : b_skew_gen
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)      b_delay[0][j] <= '0;
                else if (clear) b_delay[0][j] <= '0;
                else            b_delay[0][j] <= b_in[j];
            end
            for (k = 1; k < N; k++) begin : b_chain
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      b_delay[k][j] <= '0;
                    else if (clear) b_delay[k][j] <= '0;
                    else            b_delay[k][j] <= b_delay[k-1][j];
                end
            end
            if (j == 0) begin : b_col0
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      b_wire[0][0] <= '0;
                    else if (clear) b_wire[0][0] <= '0;
                    else            b_wire[0][0] <= b_in[0];
                end
            end else begin : b_col_delay
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      b_wire[0][j] <= '0;
                    else if (clear) b_wire[0][j] <= '0;
                    else            b_wire[0][j] <= b_delay[j-1][j];
                end
            end
        end
    endgenerate
    generate
        for (i = 0; i < N; i++) begin : a_prop
            for (j = 0; j < N-1; j++) begin : a_shift
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      a_wire[i][j+1] <= '0;
                    else if (clear) a_wire[i][j+1] <= '0;
                    else            a_wire[i][j+1] <= a_wire[i][j];
                end
            end
        end
    endgenerate
    generate
        for (j = 0; j < N; j++) begin : b_prop
            for (i = 0; i < N-1; i++) begin : b_shift
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)      b_wire[i+1][j] <= '0;
                    else if (clear) b_wire[i+1][j] <= '0;
                    else            b_wire[i+1][j] <= b_wire[i][j];
                end
            end
        end
    endgenerate
    generate
        for (i = 0; i < N; i++) begin : valid_row
            for (j = 0; j < N; j++) begin : valid_col
                if (i == 0 && j == 0) begin : v00
                    always_ff @(posedge clk or negedge rst_n) begin
                        if (!rst_n)      pe_valid[0][0] <= 1'b0;
                        else if (clear) pe_valid[0][0] <= 1'b0;
                        else            pe_valid[0][0] <= valid_in;
                    end
                end else if (j == 0) begin : v_col0
                    always_ff @(posedge clk or negedge rst_n) begin
                        if (!rst_n)      pe_valid[i][0] <= 1'b0;
                        else if (clear) pe_valid[i][0] <= 1'b0;
                        else            pe_valid[i][0] <= pe_valid[i-1][0];
                    end
                end else begin : v_shift_right
                    always_ff @(posedge clk or negedge rst_n) begin
                        if (!rst_n)      pe_valid[i][j] <= 1'b0;
                        else if (clear) pe_valid[i][j] <= 1'b0;
                        else            pe_valid[i][j] <= pe_valid[i][j-1];
                    end
                end
            end
        end
    endgenerate
    generate
        for (i = 0; i < N; i++) begin : pe_rows
            for (j = 0; j < N; j++) begin : pe_cols
                pe #(
                    .width(width),
                    .N(N),
                    .ACC_WIDTH(ACC_WIDTH),
                    .ROW(i),
                    .COL(j)
                ) u_pe (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .valid (pe_valid[i][j]),
                    .clear (clear),
                    .a_in  (a_wire[i][j]),
                    .b_in  (b_wire[i][j]),
                    .acc   (c[i][j])
                );
            end
        end
    endgenerate

`ifndef SARR_FORMAL_SBY
generate
    for (genvar i = 0; i < N; i++) begin : gen_rst_row
        for (genvar j = 0; j < N; j++) begin : gen_rst_col

            property p_sarr_rst_002;
                @(posedge clk)
                !rst_n |-> (
                    a_delay[i][j] == '0 &&
                    b_delay[i][j] == '0 &&
                    a_wire [i][j] == '0 &&
                    b_wire [i][j] == '0
                );
            endproperty

            A_SARR_RST_002: assert property (p_sarr_rst_002)
            else $error(
                "[SARR_RST_002] op pip not zero at [%0d][%0d]",
                i, j
            );

            C_SARR_RST_002: cover property (
                @(posedge clk)
                !rst_n
            );

            property p_sarr_rst_003;
            @(posedge clk)
            !rst_n |-> (pe_valid[i][j] == 1'b0);
            endproperty
            A_SARR_RST_003: assert property(p_sarr_rst_003)
            else $error("[SARR_RST_003] val not zero at [%0d][%0d]", i, j);
            C_SARR_RST_003: cover property(
                @(posedge clk)
                !rst_n
            );
            property p_sarr_rst_004;
            @(posedge clk)
            !rst_n |-> (c[i][j] == '0);
            endproperty
            A_SARR_RST_004: assert property(p_sarr_rst_004)
            else $error("[SARR_RST_004] c not zero at [%0d][%0d]", i, j);
            C_SARR_RST_004: cover property (
                @(posedge clk)
                !rst_n
            );
            //005 is covered by 002 003 004
            property p_sarr_rst_006;
                @(posedge clk)
                (!rst_n && (clear || valid_in)) |->
                (
                    a_delay[i][j] == '0 &&
                    b_delay[i][j] == '0 &&
                    a_wire[i][j]  == '0 &&
                    b_wire[i][j]  == '0 &&
                    pe_valid[i][j] == 1'b0 &&
                    c[i][j] == '0
                );
            endproperty
            A_SARR_RST_006: assert property(p_sarr_rst_006)
            else $error("[SARR_RST_006] rs is not currently the highest priority");
            C_SARR_RST_006: cover property(
                @(posedge clk)
                !rst_n && (clear || valid_in)
            );
            property p_sarr_clr_002;
                @(posedge clk)
                disable iff(!rst_n)
                clear |=> (
                    a_delay[i][j] == '0 &&
                    b_delay[i][j] == '0 &&
                    a_wire[i][j] == '0 &&
                    b_wire[i][j] == '0
                );
            endproperty
            A_SARR_CLR_002: assert property(p_sarr_clr_002)
            else $error("[SARR_CLR_002] op pip not zero at [%0d][%0d]", i, j);
            C_SARR_CLR_002: cover property(
                @(posedge clk)
                disable iff (!rst_n)
                clear
            );
            property p_sarr_clr_003;
                @(posedge clk)
                disable iff (!rst_n)
                clear |=> (pe_valid[i][j] == 1'b0);
            endproperty
            A_SARR_CLR_003: assert property(p_sarr_clr_003)
            else $error("[SARR_CLR_003] val not zero at [%0d][%0d]", i, j);
            C_SARR_CLR_003: cover property(
                @(posedge clk)
                disable iff (!rst_n)
                clear
            );
            property p_sarr_clr_004;
                @(posedge clk)
                disable iff (!rst_n)
                clear |=> (c[i][j] == '0);
            endproperty
            A_SARR_CLR_004: assert property(p_sarr_clr_004)
            else $error("[SARR_CLR_004] c not zero at [%0d][%0d]", i, j);
            C_SARR_CLR_004: cover property(
                @(posedge clk)
                disable iff (!rst_n)
                clear
            );
            //005 is coverd by 002 003 004
            property p_sarr_clr_006;
                @(posedge clk)
                disable iff(!rst_n)
                (clear && (valid_in || pe_valid[i][j])) |=> (
                    a_delay[i][j] == '0 &&
                    b_delay[i][j] == '0 &&
                    a_wire[i][j] == '0 &&
                    b_wire[i][j] == '0 &&
                    pe_valid[i][j] == 1'b0 &&
                    c[i][j] == '0
                );
            endproperty
            A_SARR_CLR_006: assert property(p_sarr_clr_006)
            else $error("[SARR_CLR_006] clear is not currently the highest priority");
            C_SARR_CLR_006: cover property(
                @(posedge clk)
                disable iff (!rst_n)
                clear && (valid_in || pe_valid[i][j])
            );
            if (j < N - 1) begin : gen_sarr_a_hop
                property p_sarr_a_003;
                    @(posedge clk)
                    disable iff(!rst_n)
                    !clear |=> (
                        a_wire[i][j+1] == $past(a_wire[i][j])
                    );
                endproperty
                A_SARR_A_003: assert property(p_sarr_a_003)
                else $error("[SARR_A_003] A propagation failed at [%0d][%0d] -> [%0d][%0d]", i, j, i, j+1);
                C_SARR_A_003: cover property(
                    @(posedge clk)
                    disable iff (!rst_n)
                    (!clear && $changed(a_wire[i][j])) |=> (
                    a_wire[i][j+1] == $past(a_wire[i][j])
                    )
                );
                //004 is asserted by 002 n 003
                C_SARR_A_004: cover property(
                    @(posedge clk)
                    disable iff (!rst_n)
                    (!clear && !pe_valid[i][j] && $changed(a_wire[i][j])) |=> (
                        a_wire[i][j+1] == $past(a_wire[i][j])
                    )
                );
            end
            if (i == 0) begin
                    property p_sarr_b_002;
                        @(posedge clk)
                        disable iff (!rst_n || clear)
                        1'b1 |-> ##(j+1)(
                            b_wire[0][j] == $past(b_in[j], j + 1)
                        );
                    endproperty
                    A_SARR_B_002: assert property(p_sarr_b_002)
                    else $error("[SARR_B_002] col=%0d failed expected delay=%0d", j, j + 1);
                    C_SARR_B_002: cover property(
                        @(posedge clk)
                        disable iff (!rst_n || clear)
                        $changed(b_in[j]) |-> ##(j + 1) (
                            b_wire[0][j] == $past(b_in[j], j + 1)
                        )
                    );
            end
            if (i < N - 1) begin : gen_sarr_b_hop
                property p_sarr_b_003;
                    @(posedge clk)
                    disable iff (!rst_n || clear)
                    !clear |=> (
                        b_wire[i+1][j] == $past(b_wire[i][j])
                    );
                endproperty
                A_SARR_B_003: assert property(p_sarr_b_003)
                else $error("[SARR_B_003] B propagation failed at [%0d][%0d] -> [%0d][%0d]", i, j, i+1, j);
                C_SARR_B_003: cover property(
                    @(posedge clk)
                    disable iff(!rst_n || clear)
                    (!clear && $changed(b_wire[i][j])) |=> (
                        b_wire[i+1][j] == $past(b_wire[i][j])
                    )
                );
                C_SARR_B_004: cover property(
                    @(posedge clk)
                    disable iff (!rst_n || clear)
                    (!clear && !pe_valid[i][j] && $changed(b_wire[i][j])) |=> (
                        b_wire[i+1][j] == $past(b_wire[i][j])
                    )
                );
                //004 is asserted by 002 n 003
            end
            if (i > 0 && j == 0) begin : gen_sarr_val_col0
                property p_sarr_val_002;
                    @(posedge clk)
                    disable iff (!rst_n)
                    !clear |=> (
                        pe_valid[i][0] == $past(pe_valid[i-1][0])
                    );
                endproperty
                A_SARR_VAL_002: assert property(p_sarr_val_002)
                else $error("[SARR_VAL_002] val propagation failed at [%0d][0]", i);
                C_SARR_VAL_002: cover property(
                    @(posedge clk)
                    disable iff (!rst_n)
                    (!clear && $changed(pe_valid[i-1][0])) |=> (
                        pe_valid[i][0] == $past(pe_valid[i-1][0])
                    )
                );
            end
            if (j > 0) begin : gen_sarr_val_row0
                property p_sarr_val_003;
                    @(posedge clk)
                    disable iff (!rst_n)
                    !clear |=> (
                        pe_valid[i][j] == $past(pe_valid[i][j-1])
                    );
                endproperty
                A_SARR_VAL_003: assert property(p_sarr_val_003)
                else $error("[SARR_VAL_003] val propagation failed at [%0d][%0d]", i, j);
                C_SARR_VAL_003: cover property(
                    @(posedge clk)
                    disable iff (!rst_n)
                    (!clear && $changed(pe_valid[i][j-1])) |=> (
                        pe_valid[i][j] == $past(pe_valid[i][j-1])
                    )
                );
            end
            property p_sarr_val_004;
                @(posedge clk)
                disable iff (!rst_n || clear)
                1'b1 |-> ##(i+j+1)(
                    pe_valid[i][j] == $past(valid_in, i+j+1)
                );
            endproperty
            A_SARR_VAL_004: assert property(p_sarr_val_004)
            else $error("[SARR_VAL_004] val propagation failed at [%0d][%0d] expected delay=%0d", i, j, i+j+1);
            C_SARR_VAL_004: cover property(
                @(posedge clk)
                disable iff (!rst_n || clear)
                $changed(valid_in) |-> ##(i+j+1) (
                    pe_valid[i][j] == $past(valid_in, i+j+1)
                )
            );
            //005 is asserted by 004, 006 is asserted by rst_003 n clr_003
            localparam int delay = i + j + 1;
            property p_sarr_align_001_002_003;
                @(posedge clk)
                disable iff (!rst_n || clear)
                pe_valid[i][j] |-> (
                    a_wire[i][j] == $past(a_in[i], delay) &&
                    b_wire[i][j] == $past(b_in[j], delay)
                );
            endproperty
            A_SARR_ALIGN_001_002_003: assert property(p_sarr_align_001_002_003)
            else $error("[SARR_ALIGN_001_002_003] alignment failed at [%0d][%0d] expected delay=%0d", i, j, delay);
            C_SARR_ALIGN_001_002_003: cover property(
                @(posedge clk)
                disable iff (!rst_n || clear)
                pe_valid[i][j] &&
                    a_wire[i][j] == $past(a_in[i], delay) &&
                    b_wire[i][j] == $past(b_in[j], delay)

            );
            property p_sarr_align_004;
                @(posedge clk)
                disable iff (!rst_n)
                (!clear && !pe_valid[i][j]) |=> (
                    c[i][j] == $past(c[i][j])
                );
            endproperty
            A_SARR_ALIGN_004: assert property(p_sarr_align_004)
            else $error("[SARR_ALIGN_004] alignment failed at [%0d][%0d]", i, j);
            C_SARR_ALIGN_004: cover property(
                @(posedge clk)
                disable iff (!rst_n)
                (!clear && !pe_valid[i][j] && ($changed(a_wire[i][j]) || $changed(b_wire[i][j]))) |=>
                (c[i][j] == $past(c[i][j])
                )
            );
            logic signed [2*width-1:0] sva_prd;
            logic signed [ACC_WIDTH-1:0] sva_prd_ext;
            assign sva_prd = a_wire[i][j] * b_wire[i][j];
            assign sva_prd_ext = {{(ACC_WIDTH-2*width){sva_prd[2*width-1]}}, sva_prd};
            property p_sarr_mac_001;
                @(posedge clk)
                disable iff (!rst_n)
                (!clear && pe_valid[i][j]) |=> (
                    c[i][j] == $past(c[i][j]) + $past(sva_prd_ext)
                );
            endproperty
            A_SARR_MAC_001: assert property(p_sarr_mac_001)
            else $error("[SARR_MAC_001] MAC failed at [%0d][%0d]", i, j);
            C_SARR_MAC_001: cover property (
                @(posedge clk)
                disable iff (!rst_n)
                (!clear &&
                pe_valid[i][j] &&
                a_wire[i][j] != '0 &&
                b_wire[i][j] != '0) |=> (
                    c[i][j] ==
                    $past(c[i][j]) + $past(sva_prd_ext)
                )
            );
            property p_sarr_mac_002;
                @(posedge clk)
                disable iff (!rst_n || clear)
                $rose(pe_valid[i][j]) |-> pe_valid[i][j][*N] ##1 !pe_valid[i][j];
            endproperty
            C_SARR_MAC_002: cover property(p_sarr_mac_002);
            //time001 is asserted by val001-004+mac001+covermac002+scb/mon
            C_SARR_TIME_003: cover property(
                @(posedge clk)
                disable iff (!rst_n || clear)
                !valid_in && pe_valid[i][j]
            );//time003 is asserted by a003 + b003 + val002/003
            //time004 is asserted by mac001 + time002 + uvm/mon/scb
            //out001 is asserted by structural rv
            //out002/003 is asserted by align 004
            end
        property p_sarr_a_002;
                @(posedge clk)
                disable iff (!rst_n || clear)
                1'b1 |-> ##(i+1)(
                    a_wire[i][0] == $past(a_in[i], i + 1)
                );
        endproperty
            A_SARR_A_002: assert property(p_sarr_a_002)
            else $error("[SARR_A_002] row=%0d failed expected delay=%0d", i, i + 1);
            C_SARR_A_002: cover property(
                @(posedge clk)
                disable iff (!rst_n || clear)
                $changed(a_in[i]) |-> ##(i + 1) (
                    a_wire[i][0] == $past(a_in[i], i + 1)
                )
            );
    end
endgenerate
property p_sarr_val_001;
    @(posedge clk)
    disable iff (!rst_n)
    !clear |=> (
        pe_valid[0][0] == $past(valid_in)
    );
endproperty
A_SARR_VAL_001: assert property(p_sarr_val_001)
else $error("[SARR_VAL_001] val propagation failed at [0][0]");
C_SARR_VAL_001: cover property(
    @(posedge clk)
    disable iff (!rst_n)
    (!clear &&
    $changed(valid_in)) |=> (
        pe_valid[0][0] == $past(valid_in)
    )
);
property p_sarr_time_002;
    @(posedge clk)
    disable iff (!rst_n || clear)
    $fell(pe_valid[0][0]) |-> ##(2*N-2) $fell(pe_valid[N-1][N-1]);
endproperty
A_SARR_TIME_002: assert property(p_sarr_time_002)
else $error("[SARR_TIME_002] completion timing failed: [0][0] -> [%0d][%0d]", N-1, N-1);
C_SARR_TIME_002: cover property (
    @(posedge clk)
    disable iff (!rst_n || clear)
    $fell(pe_valid[0][0])
    ##(2*N-2)
    $fell(pe_valid[N-1][N-1])
);
initial begin
    A_SARR_PARAM_001: assert (
        $size(c, 1) == N &&
        $size(c, 2) == N
        );

        A_SARR_PARAM_002: assert (
            $bits(a_in[0]) == width &&
            $bits(b_in[0]) == width
        );

        A_SARR_PARAM_003: assert (
            $bits(c[0][0]) == ACC_WIDTH
        );
    end
//param004 is asserted by val004 + a002/003 + b002/003 + algin 001/002/003
//op001 is asserted by rst002/003/004 + clr002/003/004
//op002 is asserted by clr002/003/004 + align 001-004 + mac001
//op003 is asserted by clr004 + align004 + mac001
`endif
endmodule
