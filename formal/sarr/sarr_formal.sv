`default_nettype none
module sarr_formal;

`ifdef FORMAL_N
    localparam int N = `FORMAL_N;
`else
    localparam int N = 8;
`endif
`ifdef FORMAL_WIDTH
    localparam int WIDTH = `FORMAL_WIDTH;
`else
    localparam int WIDTH = 8;
`endif
    localparam int ACC_WIDTH =
        2*WIDTH + ((N > 1) ? $clog2(N) : 1);

    logic clk;
    logic rst_n;
    logic valid_in;
    logic clear;
    logic past_valid;

    logic signed [WIDTH-1:0] a_in [N-1:0];
    logic signed [WIDTH-1:0] b_in [N-1:0];
    logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0];

    logic signed [N*WIDTH-1:0] formal_a_in_flat;
    logic signed [N*WIDTH-1:0] formal_b_in_flat;
    logic signed [N*N*WIDTH-1:0] formal_a_wire_flat;
    logic signed [N*N*WIDTH-1:0] formal_b_wire_flat;
    logic signed [N*N*WIDTH-1:0] formal_a_delay_flat;
    logic signed [N*N*WIDTH-1:0] formal_b_delay_flat;
    logic [N*N-1:0] formal_pe_valid_flat;
    logic signed [N*N*ACC_WIDTH-1:0] formal_c_flat;

    logic signed [WIDTH-1:0] formal_a_wire [N-1:0][N-1:0];
    logic signed [WIDTH-1:0] formal_b_wire [N-1:0][N-1:0];
    logic signed [WIDTH-1:0] formal_a_delay [N-1:0][N-1:0];
    logic signed [WIDTH-1:0] formal_b_delay [N-1:0][N-1:0];
    logic formal_pe_valid [N-1:0][N-1:0];

    systolic_arr_NxN #(
        .N(N),
        .width(WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear(clear),
        .formal_a_in_flat(formal_a_in_flat),
        .formal_b_in_flat(formal_b_in_flat),
        .formal_a_wire_flat(formal_a_wire_flat),
        .formal_b_wire_flat(formal_b_wire_flat),
        .formal_a_delay_flat(formal_a_delay_flat),
        .formal_b_delay_flat(formal_b_delay_flat),
        .formal_pe_valid_flat(formal_pe_valid_flat),
        .formal_c_flat(formal_c_flat)
    );

    generate
        for (genvar flat_i = 0; flat_i < N; flat_i++) begin : gen_unflatten_row
            assign formal_a_in_flat[flat_i*WIDTH +: WIDTH] = a_in[flat_i];
            assign formal_b_in_flat[flat_i*WIDTH +: WIDTH] = b_in[flat_i];
            for (genvar flat_j = 0; flat_j < N; flat_j++) begin : gen_unflatten_col
                localparam int FLAT_ELEM = flat_i*N + flat_j;
                assign formal_a_wire[flat_i][flat_j] = formal_a_wire_flat[FLAT_ELEM*WIDTH +: WIDTH];
                assign formal_b_wire[flat_i][flat_j] = formal_b_wire_flat[FLAT_ELEM*WIDTH +: WIDTH];
                assign formal_a_delay[flat_i][flat_j] = formal_a_delay_flat[FLAT_ELEM*WIDTH +: WIDTH];
                assign formal_b_delay[flat_i][flat_j] = formal_b_delay_flat[FLAT_ELEM*WIDTH +: WIDTH];
                assign formal_pe_valid[flat_i][flat_j] = formal_pe_valid_flat[FLAT_ELEM];
                assign c[flat_i][flat_j] = formal_c_flat[FLAT_ELEM*ACC_WIDTH +: ACC_WIDTH];
            end
        end
    endgenerate

    initial past_valid = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
    end

`ifdef PROVE_RESET
    generate
        for (genvar i = 0; i < N; i++) begin : gen_reset_row
            for (genvar j = 0; j < N; j++) begin : gen_reset_col
                always @(posedge clk) begin
                    if (!rst_n) begin
                        // A_SARR_RST_002
                            assert (
                                formal_a_delay[i][j] == '0 &&
                                formal_b_delay[i][j] == '0 &&
                                formal_a_wire[i][j] == '0 &&
                                formal_b_wire[i][j] == '0
                            );
                        // A_SARR_RST_003
                            assert (formal_pe_valid[i][j] == 1'b0);
                        // A_SARR_RST_004
                            assert (c[i][j] == '0);
                    end

                    if (!rst_n && (clear || valid_in)) begin
                        // A_SARR_RST_006
                            assert (
                                formal_a_delay[i][j] == '0 &&
                                formal_b_delay[i][j] == '0 &&
                                formal_a_wire[i][j] == '0 &&
                                formal_b_wire[i][j] == '0 &&
                                formal_pe_valid[i][j] == 1'b0 &&
                                c[i][j] == '0
                            );
                    end
                end
            end
        end
    endgenerate
`endif

`ifdef PROVE_CLEAR
    generate
        for (genvar i = 0; i < N; i++) begin : gen_clear_row
            for (genvar j = 0; j < N; j++) begin : gen_clear_col
                always @(posedge clk) begin
                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        $past(clear)
                    ) begin
                        // A_SARR_CLR_002
                            assert (
                                formal_a_delay[i][j] == '0 &&
                                formal_b_delay[i][j] == '0 &&
                                formal_a_wire[i][j] == '0 &&
                                formal_b_wire[i][j] == '0
                            );
                        // A_SARR_CLR_003
                            assert (formal_pe_valid[i][j] == 1'b0);
                        // A_SARR_CLR_004
                            assert (c[i][j] == '0);
                    end

                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        $past(clear) &&
                        ($past(valid_in) || $past(formal_pe_valid[i][j]))
                    ) begin
                            // A_SARR_CLR_006
                            assert (
                                formal_a_delay[i][j] == '0 &&
                                formal_b_delay[i][j] == '0 &&
                                formal_a_wire[i][j] == '0 &&
                                formal_b_wire[i][j] == '0 &&
                                formal_pe_valid[i][j] == 1'b0 &&
                                c[i][j] == '0
                            );
                    end
                end
            end
        end
    endgenerate
`endif

`ifdef PROVE_OPERAND
    generate
        for (genvar i = 0; i < N; i++) begin : gen_operand_row
            for (genvar j = 0; j < N; j++) begin : gen_operand_col
                always @(posedge clk) begin
                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        !$past(clear)
                    ) begin
                        if (j == 0) begin
                                // A_SARR_A_002_DELAY_ENTRY
                                assert (
                                    formal_a_delay[i][j] == $past(a_in[i])
                                );
                        end else begin
                                // A_SARR_A_002_DELAY_HOP
                                assert (
                                    formal_a_delay[i][j] ==
                                    $past(formal_a_delay[i][j-1])
                                );
                        end

                        if (i == 0) begin
                                // A_SARR_B_002_DELAY_ENTRY
                                assert (
                                    formal_b_delay[i][j] == $past(b_in[j])
                                );
                        end else begin
                                // A_SARR_B_002_DELAY_HOP
                                assert (
                                    formal_b_delay[i][j] ==
                                    $past(formal_b_delay[i-1][j])
                                );
                        end

                        if (j == 0) begin
                            if (i == 0) begin
                                    // A_SARR_A_002_ENTRY_ROW0
                                    assert (
                                        formal_a_wire[i][j] == $past(a_in[i])
                                    );
                            end else begin
                                    // A_SARR_A_002_ENTRY_SKEWED
                                    assert (
                                        formal_a_wire[i][j] ==
                                        $past(formal_a_delay[i][i-1])
                                    );
                            end
                        end else begin
                                // A_SARR_A_003
                                assert (
                                    formal_a_wire[i][j] ==
                                    $past(formal_a_wire[i][j-1])
                                );
                        end

                        if (i == 0) begin
                            if (j == 0) begin
                                    // A_SARR_B_002_ENTRY_COL0
                                    assert (
                                        formal_b_wire[i][j] == $past(b_in[j])
                                    );
                            end else begin
                                    // A_SARR_B_002_ENTRY_SKEWED
                                    assert (
                                        formal_b_wire[i][j] ==
                                        $past(formal_b_delay[j-1][j])
                                    );
                            end
                        end else begin
                                // A_SARR_B_003
                                assert (
                                    formal_b_wire[i][j] ==
                                    $past(formal_b_wire[i-1][j])
                                );
                        end
                    end
                end
            end
        end
    endgenerate
`endif

`ifdef PROVE_VALID
    generate
        for (genvar i = 0; i < N; i++) begin : gen_valid_row
            for (genvar j = 0; j < N; j++) begin : gen_valid_col
                always @(posedge clk) begin
                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        !$past(clear)
                    ) begin
                        if (i == 0 && j == 0) begin
                                // A_SARR_VAL_001
                                assert (
                                    formal_pe_valid[i][j] == $past(valid_in)
                                );
                        end else if (j == 0) begin
                                // A_SARR_VAL_002
                                assert (
                                    formal_pe_valid[i][j] ==
                                    $past(formal_pe_valid[i-1][j])
                                );
                        end else begin
                                // A_SARR_VAL_003
                                assert (
                                    formal_pe_valid[i][j] ==
                                    $past(formal_pe_valid[i][j-1])
                                );
                        end
                    end
                end
            end
        end
    endgenerate
`endif

`ifdef PROVE_MAC_HOLD
    generate
        for (genvar i = 0; i < N; i++) begin : gen_mac_row
            for (genvar j = 0; j < N; j++) begin : gen_mac_col
                logic signed [2*WIDTH-1:0] product_model;
                logic signed [ACC_WIDTH-1:0] product_model_ext;

                assign product_model =
                    formal_a_wire[i][j] * formal_b_wire[i][j];
                assign product_model_ext = {
                    {(ACC_WIDTH-2*WIDTH){product_model[2*WIDTH-1]}},
                    product_model
                };

                always @(posedge clk) begin
                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        !$past(clear) &&
                        $past(formal_pe_valid[i][j])
                    ) begin
                            // A_SARR_MAC_001_003
                            assert (
                                c[i][j] ==
                                $past(c[i][j]) + $past(product_model_ext)
                            );
                    end

                    if (
                        past_valid &&
                        rst_n &&
                        $past(rst_n) &&
                        !$past(clear) &&
                        !$past(formal_pe_valid[i][j])
                    ) begin
                            // A_SARR_ALIGN_004_MAC_005_OUT_002_003
                            assert (c[i][j] == $past(c[i][j]));
                    end
                end
            end
        end
    endgenerate
`endif

`ifdef COVER_SARR
    always @(posedge clk) begin
            C_SARR_RST_006: cover (
                past_valid && !rst_n && clear && valid_in
            );

            C_SARR_CLR_006: cover (
                past_valid && rst_n && clear && valid_in
            );

            C_SARR_VAL_001_WAVEFRONT: cover (
                past_valid &&
                rst_n &&
                formal_pe_valid[0][0] &&
                !formal_pe_valid[N-1][N-1]
            );

            C_SARR_TIME_003_IN_FLIGHT: cover (
                past_valid &&
                rst_n &&
                !valid_in &&
                formal_pe_valid[N-1][N-1]
            );

            C_SARR_ALIGN_001_002_003_LAST_PE: cover (
                past_valid &&
                rst_n &&
                formal_pe_valid[N-1][N-1] &&
                formal_a_wire[N-1][N-1] != '0 &&
                formal_b_wire[N-1][N-1] != '0
            );

            C_SARR_MAC_001_NONZERO_RESULT: cover (
                past_valid &&
                rst_n &&
                c[N-1][N-1] != '0
            );
    end
`endif
endmodule
`default_nettype wire
