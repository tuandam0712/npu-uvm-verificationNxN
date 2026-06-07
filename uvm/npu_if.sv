interface npu_if #(
    parameter int N = 8,
    parameter int width = 8,
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1)
)(input logic clk);

    logic rst_n;
    logic start;
    logic done;
    logic valid_in;
    logic signed [width-1:0] a [N-1:0];
    logic signed [width-1:0] b [N-1:0];
    logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0];

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output rst_n, start;
        output a, b;
        input  done, valid_in, c;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #0 output #0;
        input rst_n, start, done, valid_in;
        input a, b, c;
    endclocking

endinterface
