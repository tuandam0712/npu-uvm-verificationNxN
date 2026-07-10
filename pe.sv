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
endmodule
