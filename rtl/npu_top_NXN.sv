module npu_top_NXN #(
    parameter int N = 8,
    parameter int width = 8,
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1)
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [width-1:0] a_in [N-1:0],
    input  logic signed [width-1:0] b_in [N-1:0],
    output logic done,
    output logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0],
    output logic valid_in
);

    logic ctrl_valid_in;
    logic ctrl_clear;

    sa_controller_NxN #(
        .N(N)
    ) u_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .valid_in (ctrl_valid_in),
        .clear    (ctrl_clear),
        .done     (done)
    );

    systolic_arr_NxN #(
        .N(N),
        .width(width),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_arr (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (ctrl_valid_in),
        .clear    (ctrl_clear),
        .a_in     (a_in),
        .b_in     (b_in),
        .c        (c)
    );

    assign valid_in = ctrl_valid_in;

endmodule
