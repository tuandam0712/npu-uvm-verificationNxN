`ifndef APB_REG_MAP_SV
`define APB_REG_MAP_SV
localparam bit [31:0] APB_CONTROL_ADDR = 32'h0000_0000;
localparam bit [31:0] APB_STATUS_ADDR  = 32'h0000_0004;
localparam bit [31:0] APB_A_BASE = 32'h0000_0010;
localparam bit [31:0] APB_B_BASE = 32'h0000_0110;
localparam bit [31:0] APB_C_BASE = 32'h0000_0210;
localparam int APB_N = 8;
localparam int APB_WORD_BYTES = 4;
localparam int APB_DATA_WIDTH = 8;

function automatic bit [31:0] apb_a_addr(int row, int col);
    return APB_A_BASE + (row * APB_N + col) * APB_WORD_BYTES;
endfunction
function automatic bit [31:0] apb_b_addr(int row, int col);
    return APB_B_BASE + (row * APB_N + col) * APB_WORD_BYTES;
endfunction
function automatic bit [31:0] apb_c_addr(int row, int col);
    return APB_C_BASE + (row * APB_N + col) * APB_WORD_BYTES;
endfunction
`endif