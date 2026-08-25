module apb_npu_wrapper #(
    parameter int N          = 8,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 2*DATA_WIDTH + ((N > 1) ? $clog2(N) : 1)
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
    localparam logic [31:0] ADDR_B_BASE  = 32'h0000_0110;
    localparam logic [31:0] ADDR_C_BASE  = 32'h0000_0210;
    localparam int NUM_ELEMS = N * N;
    logic apb_write;
    logic apb_read;
    logic start_pulse, busy, done;
    logic [DATA_WIDTH-1:0] a_regs [0:NUM_ELEMS-1];
    logic [DATA_WIDTH-1:0] b_regs [0:NUM_ELEMS-1];
    logic signed [ACC_WIDTH-1:0] c_regs [0:NUM_ELEMS-1];
    integer i;
    logic signed [DATA_WIDTH-1:0] npu_a_in [0:N-1];
    logic signed [DATA_WIDTH-1:0] npu_b_in [0:N-1];
    logic signed [ACC_WIDTH-1:0]  npu_c    [0:N-1][0:N-1];
    logic npu_done;
    logic npu_valid_in;
    logic [$clog2(N+1)-1:0] feed_idx;
    logic feeding;
    logic start_cmd;
    assign apb_write = psel && penable &&  pwrite;
    assign apb_read  = psel && penable && !pwrite;
    assign pready  = 1'b1;
    logic word_aligned;
    logic addr_a_hit;
    logic addr_b_hit;
    logic addr_c_hit;
    logic legal_wr;
    logic legal_rd;
    assign word_aligned = (paddr[1:0] == 2'b00);
    assign addr_a_hit = word_aligned && (paddr >= ADDR_A_BASE) && (paddr < ADDR_A_BASE + NUM_ELEMS*4);
    assign addr_b_hit =word_aligned && (paddr >= ADDR_B_BASE) && (paddr < ADDR_B_BASE + NUM_ELEMS*4);
    assign addr_c_hit =word_aligned && (paddr >= ADDR_C_BASE) && (paddr < ADDR_C_BASE + NUM_ELEMS*4);
    assign legal_wr = word_aligned && (
        ((paddr == ADDR_CONTROL) && (!pwdata[0] || !busy)) || ((addr_a_hit || addr_b_hit) && !busy)
    );
    assign legal_rd = word_aligned && (
        (paddr == ADDR_STATUS) || addr_c_hit
    );
    assign pslverr = (apb_write && !legal_wr) || (apb_read && !legal_rd);
    assign start_cmd = apb_write && legal_wr && (paddr == ADDR_CONTROL) && pwdata[0];
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            start_pulse <= 1'b0;
            busy        <= 1'b0;
            done        <= 1'b0;
            feeding  <= 1'b0;
            feed_idx <= '0;
            for (i = 0; i < NUM_ELEMS; i++) begin
                a_regs[i] <= '0;
                b_regs[i] <= '0;
                c_regs[i] <= '0;
            end
        end else begin
            start_pulse <= 1'b0;
            if (start_cmd && !busy) begin
                start_pulse <= 1'b1;
                busy        <= 1'b1;
                done        <= 1'b0;
            end
            if (apb_write && legal_wr) begin
                if (addr_a_hit) begin
                    a_regs[(paddr - ADDR_A_BASE) >> 2]
                        <= pwdata[DATA_WIDTH-1:0];
                end else if (addr_b_hit) begin
                    b_regs[(paddr - ADDR_B_BASE) >> 2]
                        <= pwdata[DATA_WIDTH-1:0];
                end
            end
            if (start_cmd && !busy) begin
                feeding  <= 1'b0;
                feed_idx <= '0;
            end

            if (npu_valid_in) begin
                feeding <= 1'b1;

                if (feed_idx < N-1) begin
                    feed_idx <= feed_idx + 1'b1;
                end else begin
                    feeding <= 1'b0;
                end
            end
            if (npu_done) begin
                busy <= 1'b0;
                done <= 1'b1;

                for (i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        c_regs[i*N + j] <= npu_c[i][j];
                    end
                end
            end
        end
    end
    always_comb begin
        prdata = 32'h0;
        if (apb_read && legal_rd) begin
            if (paddr == ADDR_STATUS) begin
                prdata[0] = done;
                prdata[1] = busy;
            end else if (addr_c_hit) begin
                prdata = 32'($signed(
                    c_regs[(paddr - ADDR_C_BASE) >> 2]
                ));
            end
        end
    end
    genvar gi;
    generate
        for (gi = 0; gi < N; gi++) begin : GEN_NPU_INPUTS
            always_comb begin
                npu_a_in[gi] = '0;
                npu_b_in[gi] = '0;

                if (npu_valid_in && (feed_idx < N)) begin
                    npu_a_in[gi] = a_regs[gi*N + feed_idx];
                    npu_b_in[gi] = b_regs[feed_idx*N + gi];
                end
            end
        end
    endgenerate
    npu_top_NXN #(
        .N(N),
        .width(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_npu (
        .clk      (pclk),
        .rst_n    (presetn),
        .start    (start_pulse),
        .a_in     (npu_a_in),
        .b_in     (npu_b_in),
        .done     (npu_done),
        .c        (npu_c),
        .valid_in (npu_valid_in)
    );
endmodule
