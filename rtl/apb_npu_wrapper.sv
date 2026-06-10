module apb_npu_wrapper #(
    parameter int N          = 8,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    input  logic        pclk,
    input  logic        presetn,

    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,

    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);

    localparam logic [31:0] ADDR_CONTROL = 32'h0000_0000;
    localparam logic [31:0] ADDR_STATUS  = 32'h0000_0004;
    localparam logic [31:0] ADDR_A_BASE  = 32'h0000_0010;
    localparam logic [31:0] ADDR_B_BASE  = 32'h0000_0040;
    localparam logic [31:0] ADDR_C_BASE  = 32'h0000_0080;

    localparam int NUM_ELEMS = N * N;

    logic apb_write;
    logic apb_read;

    assign apb_write = psel && penable &&  pwrite;
    assign apb_read  = psel && penable && !pwrite;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

endmodule