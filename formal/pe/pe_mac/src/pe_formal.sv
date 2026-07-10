`default_nettype none

module pe_formal;

    localparam int N         = 8;
    localparam int WIDTH     = 8;
    localparam int ACC_WIDTH = 2*WIDTH + $clog2(N);

    logic clk;

    logic rst_n;
    logic clear;
    logic valid;
    logic signed [WIDTH-1:0] a_in;
    logic signed [WIDTH-1:0] b_in;

    logic signed [ACC_WIDTH-1:0] acc;
    logic past_valid;

    logic signed [2*WIDTH-1:0] product_model;
    logic signed [ACC_WIDTH-1:0] product_model_ext;

    assign product_model = a_in * b_in;

    assign product_model_ext = {{(ACC_WIDTH - 2*WIDTH){product_model[2*WIDTH-1]}},product_model};

    pe #(
        .N(N),
        .width(WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .valid(valid),
        .a_in(a_in),
        .b_in(b_in),
        .acc(acc)
    );

    initial past_valid = 1'b0;

    always @(posedge clk) begin
        past_valid <= 1'b1;
    end

`ifdef PROVE_HOLD
    always @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n) && !$past(clear) && !$past(valid)) begin
            A_PE_HOLD_001:
                assert (acc == $past(acc));
        end
    end
`endif

`ifdef PROVE_RESET
    always @(posedge clk) begin
        if (!rst_n) begin
            A_PE_RST_002_003:
                assert (acc == '0);
        end

        if (!rst_n && (clear || valid)) begin
            A_PE_RST_004:
                assert (acc == '0);
        end
    end
`endif

`ifdef PROVE_CLEAR
    always @(posedge clk) begin
        if (past_valid && $past(rst_n) && $past(clear)) begin
            A_PE_CLR_002_003:
                assert (acc == '0);
        end

        if (past_valid && $past(rst_n) && $past(clear) && $past(valid)) begin
            A_PE_CLR_004:
                assert (acc == '0);
        end
    end
`endif

`ifdef PROVE_MAC
    always @(posedge clk) begin
        if (past_valid && rst_n && $past(rst_n) && !$past(clear) && $past(valid)) begin
            A_PE_MAC_001_002_003:
                assert (
                    acc == $past(acc) + $past(product_model_ext)
                );
        end
    end
`endif

endmodule

`default_nettype wire