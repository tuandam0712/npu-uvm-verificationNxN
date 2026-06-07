`timescale 1ns/1ps

module tb_rtl_random;
    parameter int N = 8;
    parameter int width = 8;
    parameter int NUM_TESTS = 10;
    localparam int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1);

    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic valid_in;
    logic signed [width-1:0] a_in [N-1:0];
    logic signed [width-1:0] b_in [N-1:0];
    logic signed [ACC_WIDTH-1:0] c [N-1:0][N-1:0];

    npu_top_NXN #(
        .N(N),
        .width(width),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .a_in     (a_in),
        .b_in     (b_in),
        .done     (done),
        .c        (c),
        .valid_in (valid_in)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic void compute_expected(
        input  int A [N-1:0][N-1:0],
        input  int B [N-1:0][N-1:0],
        output longint signed exp [N-1:0][N-1:0]
    );
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                exp[i][j] = 0;
                for (int k = 0; k < N; k++) begin
                    exp[i][j] += longint'(A[i][k]) * longint'(B[k][j]);
                end
            end
        end
    endfunction

    task automatic reset_dut();
        rst_n = 1'b0;
        start = 1'b0;
        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
    endtask

    task automatic run_one_test(
        input int test_id,
        input int A [N-1:0][N-1:0],
        input int B [N-1:0][N-1:0],
        output bit passed
    );
        automatic longint signed exp [N-1:0][N-1:0];
        automatic int errors;

        compute_expected(A, B, exp);
        errors = 0;
        passed = 1'b0;

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(valid_in === 1'b1);
        for (int col = 0; col < N; col++) begin
            for (int i = 0; i < N; i++) begin
                a_in[i] = A[i][col];
                b_in[i] = B[col][i];
            end
            @(posedge clk);
        end

        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end

        fork
            begin
                wait(done === 1'b1);
            end
            begin
                repeat (1000) @(posedge clk);
                errors = -1;
            end
        join_any
        disable fork;

        if (errors == -1) begin
            $display("RTL_TEST_%0d FAIL: timeout", test_id);
            return;
        end

        @(posedge clk);

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (longint'(c[i][j]) != exp[i][j]) begin
                    errors++;
                    if (errors <= 10) begin
                        $display("RTL_TEST_%0d mismatch [%0d][%0d]: act=%0d exp=%0d",
                            test_id, i, j, c[i][j], exp[i][j]);
                    end
                end
            end
        end

        passed = (errors == 0);
        if (passed) $display("RTL_TEST_%0d PASS", test_id);
        else        $display("RTL_TEST_%0d FAIL: errors=%0d", test_id, errors);
    endtask

    initial begin
        automatic int A [N-1:0][N-1:0];
        automatic int B [N-1:0][N-1:0];
        automatic int seed;
        automatic int pass_count;
        automatic int fail_count;
        automatic bit passed;

        seed = 12345;
        pass_count = 0;
        fail_count = 0;

        reset_dut();

        for (int test_id = 1; test_id <= NUM_TESTS; test_id++) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    A[i][j] = ($random(seed) % 128) - 64;
                    B[i][j] = ($random(seed) % 128) - 64;
                end
            end

            run_one_test(test_id, A, B, passed);
            if (passed) pass_count++;
            else        fail_count++;

            repeat (10) @(posedge clk);
        end

        $display("RTL_RANDOM_SUMMARY: total=%0d pass=%0d fail=%0d", NUM_TESTS, pass_count, fail_count);
        if (fail_count == 0) $finish;
        else                 $fatal(1, "RTL random test failed");
    end
endmodule
