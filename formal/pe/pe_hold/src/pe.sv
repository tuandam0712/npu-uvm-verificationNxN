module pe #(
    parameter int width = 8,
    parameter int N = 8,
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1),
    parameter int ROW = 0,
    parameter int COL = 0
) (
    input  logic clk,
    input  logic rst_n,
    input  logic valid,
    input  logic signed [width-1:0] a_in,
    input  logic signed [width-1:0] b_in,
    input  logic clear,
    output logic signed [ACC_WIDTH-1:0] acc
);
    logic signed [ACC_WIDTH-1:0] acc_reg;
    logic signed [2*width-1:0] product;
    logic signed [ACC_WIDTH-1:0] product_ext;
    assign product     = a_in * b_in;
    assign product_ext = {{(ACC_WIDTH-2*width){product[2*width-1]}}, product};
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg <= '0;
        end else if (clear) begin
            acc_reg <= '0;
        end else if (valid) begin
            acc_reg <= acc_reg + product_ext;
        end
    end
        assign acc = acc_reg;
`ifndef PE_FORMAL_SBY
    property p_pe_hold_001;
        @(posedge clk)
        disable iff(!rst_n)
        (!clear && !valid) |=> ($past(acc_reg) == acc_reg);
    endproperty
    A_PE_HOLD_001:
    assert property(p_pe_hold_001)
    else $error("[PE_SVA] HOLD mismatch ROW=%0d COL=%0d time=%0t past_clear=%0b past_valid=%0b clear=%0b valid=%0b past_acc=%0d acc=%0d",
        ROW, COL, $time,
        $past(clear),
        $past(valid),
        $sampled(clear),
        $sampled(valid),
        $past(acc_reg),
        $sampled(acc_reg)
    );
    property p_pe_rst_002_003;
        @(posedge clk)
        (!rst_n) |-> (acc_reg == '0);
    endproperty
    A_PE_RST_002_003:
    assert property(p_pe_rst_002_003)
    else $error("[PE_SVA] RST mismatch ROW=%0d COL=%0d time=%0t rst_n=%0b acc=%0d",
        ROW, COL, $time,
        $sampled(rst_n),
        $sampled(acc_reg)
    );
    property p_pe_rst_004;
        @(posedge clk)
        (!rst_n && (clear || valid)) |-> (acc_reg == '0);
    endproperty
    A_PE_RST_004:
    assert property(p_pe_rst_004)
    else $error("[PE_SVA] RST mismatch ROW=%0d COL=%0d time=%0t rst_n=%0b clear=%0b valid=%0b acc=%0d",
        ROW, COL, $time,
        $sampled(rst_n),
        $sampled(clear),
        $sampled(valid),
        $sampled(acc_reg)
    );
    property p_pe_clr_002_003;
        @(posedge clk)
        disable iff(!rst_n)
        clear |=> (acc_reg == '0);
    endproperty
    A_PE_CLR_002_003:
    assert property(p_pe_clr_002_003)
    else $error("[PE_SVA] CLR mismatch ROW=%0d COL=%0d time=%0t clear=%0b valid=%0b acc=%0d",
        ROW, COL, $time,
        $sampled(clear),
        $sampled(valid),
        $sampled(acc_reg)
    );
    property p_pe_clr_004;
        @(posedge clk)
        disable iff(!rst_n)
        (clear && valid) |=> (acc_reg == '0);
    endproperty
    A_PE_CLR_004:
    assert property(p_pe_clr_004)
    else $error("[PE_SVA] CLR mismatch ROW=%0d COL=%0d time=%0t clear=%0b valid=%0b acc=%0d",
        ROW, COL, $time,
        $sampled(clear),
        $sampled(valid),
        $sampled(acc_reg)
    );
    property p_pe_mac_001_002_003;
        @(posedge clk)
        disable iff(!rst_n)
        (!clear && valid) |=> (acc_reg == $past(acc_reg) + $past(product_ext));
    endproperty
    A_PE_MAC_001_002_003:
    assert property(p_pe_mac_001_002_003)
    else $error("[PE_SVA] MAC mismatch ROW=%0d COL=%0d time=%0t clear=%0b valid=%0b past_acc=%0d acc=%0d product_ext=%0d",
        ROW, COL, $time,
        $sampled(clear),
        $sampled(valid),
        $past(acc_reg),
        $sampled(acc_reg),
        $sampled(product_ext)
    );
    C_PE_HOLD_001:
    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        (!clear && !valid)
    );

    C_PE_RST_002_003:
    cover property (
        @(posedge clk)
        !rst_n
    );

    C_PE_RST_004:
    cover property (
        @(posedge clk)
        !rst_n && (clear || valid)
    );

    C_PE_CLR_002_003:
    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        clear
    );

    C_PE_CLR_004:
    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        clear && valid
    );

    C_PE_MAC_001_002_003:
    cover property (
        @(posedge clk)
        disable iff (!rst_n)
        !clear && valid
    );
`endif
endmodule
