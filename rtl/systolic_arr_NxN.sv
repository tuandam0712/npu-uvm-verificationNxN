module systolic_arr_NxN #(
    parameter int N = 8,
    parameter int width = 8,
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic clear,
    input  logic signed [width-1:0] a_in [N-1:0],
    input  logic signed [width-1:0] b_in [N-1:0],
    output logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0]
);
    logic signed [width-1:0] a_wire [N-1:0][N-1:0];
    logic signed [width-1:0] b_wire [N-1:0][N-1:0];
    logic signed [width-1:0] a_delay [N-1:0][N-1:0];
    logic signed [width-1:0] b_delay [N-1:0][N-1:0];
    logic pe_valid [N-1:0][N-1:0];
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
    generate
        for (genvar i = 0; i < N; i++) begin : gen_valid_latency
            for (genvar j = 0; j < N; j++) begin : gen_valid_latency_col
                localparam int LAT = i + j + 1;
                property p_valid_wavefront;
                    @(posedge clk) disable iff (!rst_n || clear)
                    valid_in |-> ##LAT pe_valid[i][j];
                endproperty
                A_VALID_WAVEFRONT: assert property(p_valid_wavefront)
                else $error("[ARR_SVA] Valid wavefront failed at PE[%0d][%0d], expected delay %0d", i, j, LAT);
            end
        end
    endgenerate
    generate
        for (genvar i = 0; i < N; i++) begin : gen_a_latency
            for (genvar j = 0; j < N; j++) begin : gen_a_latency_col
                localparam int LAT = i + j + 1;
                property p_a_delay;
                    @(posedge clk) disable iff (!rst_n || clear)
                    pe_valid[i][j] |-> (a_wire[i][j] == $past(a_in[i], LAT));
                endproperty
                A_A_DELAY: assert property(p_a_delay)
                else $error("[ARR_SVA] A operand mismatch at PE[%0d][%0d], expected past value of a_in[%0d] from %0d cycles ago", i, j, i, LAT);
            end
        end
    endgenerate
    generate
        for (genvar i = 0; i < N; i++) begin : gen_b_latency
            for (genvar j = 0; j < N; j++) begin : gen_b_latency_col
                localparam int LAT = i + j + 1;
                property p_b_delay;
                    @(posedge clk) disable iff (!rst_n || clear)
                    pe_valid[i][j] |-> (b_wire[i][j] == $past(b_in[j], LAT));
                endproperty
                A_B_DELAY: assert property(p_b_delay)
                else $error("[ARR_SVA] B operand mismatch at PE[%0d][%0d], expected past value of b_in[%0d] from %0d cycles ago", i, j, j, LAT);
            end
        end
    endgenerate
    generate
        for (genvar i = 0; i < N; i++) begin : gen_nox
            for (genvar j = 0; j < N; j++) begin : gen_nox_col
                property p_no_x_when_valid;
                    @(posedge clk) disable iff (!rst_n)
                    pe_valid[i][j] |->
                        (!$isunknown(a_wire[i][j]) && !$isunknown(b_wire[i][j]));
                endproperty
                A_NO_X_WHEN_VALID: assert property(p_no_x_when_valid);
            end
        end
    endgenerate
endmodule
