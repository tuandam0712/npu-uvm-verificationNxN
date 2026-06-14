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
    //sva
    property p_pe_reset_clear_acc;
        @(posedge clk)
        !rst_n |=> (acc_reg == '0);
    endproperty

    A_PE_RESET_CLEAR_ACC:
    assert property(p_pe_reset_clear_acc)
    else $error("[PE_SVA] reset active but acc_reg != 0");


    property p_pe_clear_priority;
        @(posedge clk)
        disable iff(!rst_n)
        clear |=> (acc_reg == '0);
    endproperty

    A_PE_CLEAR_PRIORITY:
    assert property(p_pe_clear_priority)
    else $error("[PE_SVA] clear active but acc_reg != 0");


    property p_pe_hold_when_invalid;
        @(posedge clk)
        disable iff(!rst_n)
        ($past(rst_n) &&
        $past(!clear && !valid) &&
        !clear && !valid)
        |-> (acc_reg == $past(acc_reg));
    endproperty

    A_PE_HOLD_WHEN_INVALID:
    assert property(p_pe_hold_when_invalid)
    else $error(
        "[PE_SVA] HOLD mismatch ROW=%0d COL=%0d time=%0t past_clear=%0b past_valid=%0b clear=%0b valid=%0b past_acc=%0d acc=%0d",
        ROW, COL, $time,
        $past(clear),
        $past(valid),
        $sampled(clear),
        $sampled(valid),
        $past(acc_reg),
        $sampled(acc_reg)
    );


    property p_pe_mac_when_valid;
        @(posedge clk)
        disable iff(!rst_n)
        (valid && !clear)
        |=>
        (
            acc_reg ==
            $past(acc_reg) + ($past(a_in) * $past(b_in))
        );
    endproperty

    A_PE_MAC_WHEN_VALID:
    assert property(p_pe_mac_when_valid)
    else $error("[PE_SVA] MAC mismatch when valid=1 clear=0");
endmodule
