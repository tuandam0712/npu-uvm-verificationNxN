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
    logic start_pulse, busy, done;
    logic [DATA_WIDTH-1:0] a_regs [0:NUM_ELEMS-1];
    logic [DATA_WIDTH-1:0] b_regs [0:NUM_ELEMS-1];
    logic [ACC_WIDTH-1:0] c_regs [0:NUM_ELEMS-1];
    integer i;
    assign apb_write = psel && penable &&  pwrite;
    assign apb_read  = psel && penable && !pwrite;
    assign pready  = 1'b1;
    assign pslverr = 1'b0;
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            start_pulse <= 1'b0;
            busy        <= 1'b0;
            done        <= 1'b0;
            for (i = 0; i < NUM_ELEMS; i++) begin
                a_regs[i] <= '0;
                b_regs[i] <= '0;
                c_regs[i] <= '0;
            end
        end else begin
            start_pulse <= 1'b0;
            if (apb_write && (paddr == ADDR_CONTROL)) begin
                if (pwdata[0]) begin
                    start_pulse <= 1'b1;
                    busy        <= 1'b1;
                    done        <= 1'b0;
                end
            end
            if (apb_write) begin
                if((paddr >= ADDR_A_BASE) && (paddr < ADDR_A_BASE + NUM_ELEMS*4)) begin
                    a_regs[(paddr - ADDR_A_BASE) >> 2] <= pwdata[DATA_WIDTH-1:0];
                end else if((paddr >= ADDR_B_BASE) && (paddr < ADDR_B_BASE + NUM_ELEMS*4)) begin
                    b_regs[(paddr - ADDR_B_BASE) >> 2] <= pwdata[DATA_WIDTH-1:0];
                end
            end
            if (start_pulse) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end
    always_comb begin
        prdata = 32'h0;
        if (apb_read) begin
            case (paddr)
                ADDR_STATUS: begin
                    prdata[0] = done;
                    prdata[1] = busy;
                end
                default: begin
                    prdata = 32'h0;
                    if((paddr >= ADDR_C_BASE) && (paddr < ADDR_C_BASE + NUM_ELEMS*4)) begin
                        prdata = c_regs[(paddr - ADDR_C_BASE) >> 2];
                    end
                end
            endcase
        end
    end
endmodule
