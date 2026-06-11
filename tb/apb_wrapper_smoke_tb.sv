module apb_wrapper_smoke_tb;
    localparam int N = 8;
    localparam int NUM_TESTS = 100;
    logic        pclk;
    logic        presetn;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic [31:0] status_data;
    localparam logic [31:0] ADDR_CONTROL = 32'h0000_0000;
    localparam logic [31:0] ADDR_STATUS  = 32'h0000_0004;
    localparam logic [31:0] ADDR_A_BASE  = 32'h0000_0010;
    localparam logic [31:0] ADDR_B_BASE  = 32'h0000_0110;
    localparam logic [31:0] ADDR_C_BASE  = 32'h0000_0210;
    logic [31:0] read_data;
    int row;
    int col;
    int idx;
    int expected;
    int error_count;
    int A_mat [0:N-1][0:N-1];
    int B_mat [0:N-1][0:N-1];
    int C_exp [0:N-1][0:N-1];
    int k;
    int test_id;
    int val;
    apb_npu_wrapper #(
        .N(N),
        .DATA_WIDTH(8),
        .ACC_WIDTH(32)
    ) dut (
        .pclk    (pclk),
        .presetn (presetn),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );
    task automatic apb_write_task(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        begin
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            pwrite  <= 1'b1;
            paddr   <= addr;
            pwdata  <= data;

            @(posedge pclk);
            penable <= 1'b1;

            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= 32'h0;
            pwdata  <= 32'h0;
        end
    endtask
    task automatic apb_read_task(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        begin
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= addr;
            pwdata  <= 32'h0;

            @(posedge pclk);
            penable <= 1'b1;

            #1;
            data = prdata;

            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            paddr   <= 32'h0;
        end
    endtask
    task automatic calc_golden();
        for (row = 0; row < N; row++) begin
            for (col = 0; col < N; col++) begin
                C_exp[row][col] = 0;

                for (k = 0; k < N; k++) begin
                    C_exp[row][col] += A_mat[row][k] * B_mat[k][col];
                end
            end
        end
    endtask
    initial begin
        pclk = 1'b0;
        forever #5 pclk = ~pclk; // 100MHz clock
    end
    initial begin
        error_count = 0;
        $display("APB matrix smoke test started");

        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 32'h0;
        pwdata  = 32'h0;
        presetn = 1'b0;

        repeat (3) @(posedge pclk);
        presetn = 1'b1;
            for (test_id = 0; test_id < NUM_TESTS; test_id++) begin
            $display("APB random test %0d started", test_id);
            // Write A = identity matrix
            for (row = 0; row < N; row++) begin
                for (col = 0; col < N; col++) begin
                    idx = row*N + col;

                    val = $urandom_range(0, 3);
                    A_mat[row][col] = val;

                    apb_write_task(ADDR_A_BASE + 4*idx, A_mat[row][col]);
                end
            end

            // Write B = simple matrix: B[row][col] = row + col + 1
            for (row = 0; row < N; row++) begin
                for (col = 0; col < N; col++) begin
                    idx = row*N + col;

                    val = $urandom_range(0, 3);
                    B_mat[row][col] = val;

                    apb_write_task(ADDR_B_BASE + 4*idx, B_mat[row][col]);
                end
            end
            calc_golden();
            // Start NPU
            apb_write_task(ADDR_CONTROL, 32'h1);

            // Poll STATUS.done
            status_data = 32'h0;
            repeat (100) begin
                apb_read_task(ADDR_STATUS, status_data);
                if (status_data[0]) begin
                    break;
                end
            end

            if (!status_data[0]) begin
                $error("Timeout waiting for NPU done. STATUS=%h", status_data);
            end else begin
                $display("NPU done detected. STATUS=%h", status_data);
            end

            // Read C and compare with B
            for (row = 0; row < N; row++) begin
                for (col = 0; col < N; col++) begin
                    idx = row*N + col;
                    expected = C_exp[row][col];

                    apb_read_task(ADDR_C_BASE + 4*idx, read_data);

                    if (read_data !== expected) begin
                        $error("C mismatch at [%0d][%0d]. Got=%0d Expected=%0d",
                            row, col, read_data, expected);
                        error_count++;
                    end
                end
            end
        end
        if (error_count == 0) begin
           $display("APB random regression PASS: %0d tests", NUM_TESTS);
        end else begin
            $fatal(1, "APB random regression FAILED with %0d errors", error_count);
        end

        #20;
        $finish;
    end
endmodule