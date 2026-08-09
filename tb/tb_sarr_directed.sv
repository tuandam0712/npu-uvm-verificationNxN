`timescale 1ns/1ps

module tb_sarr_directed;
    parameter int N = 8;
    parameter int width = 8;
    parameter int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1);

    typedef logic signed [width-1:0] operand_t;
    typedef logic signed [ACC_WIDTH-1:0] acc_t;

    logic clk;
    logic rst_n;
    logic valid_in;
    logic clear;
    operand_t a_in [N-1:0];
    operand_t b_in [N-1:0];
    acc_t c [N-1:0][N-1:0];

    operand_t matrix_a [N-1:0][N-1:0];
    operand_t matrix_b [N-1:0][N-1:0];
    acc_t expected [N-1:0][N-1:0];
    acc_t snapshot [N-1:0][N-1:0];

    int pass_cnt;
    int fail_cnt;

    systolic_arr_NxN #(
        .N(N),
        .width(width),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .clear(clear),
        .a_in(a_in),
        .b_in(b_in),
        .c(c)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic report_case(
        input string test_name,
        input bit failed
    );
        if (failed) begin
            fail_cnt++;
            $error("[%s] FAILED", test_name);
        end else begin
            pass_cnt++;
            $display("[%s] PASSED", test_name);
        end
    endtask

    task automatic init_signals;
        rst_n = 1'b1;
        clear = 1'b0;
        valid_in = 1'b0;
        pass_cnt = 0;
        fail_cnt = 0;

        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
            for (int j = 0; j < N; j++) begin
                matrix_a[i][j] = '0;
                matrix_b[i][j] = '0;
                expected[i][j] = '0;
                snapshot[i][j] = '0;
            end
        end
    endtask

    task automatic check_all_zero(input string test_name);
        bit failed;
        failed = 1'b0;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (dut.a_delay[i][j] !== '0) begin
                    $display("[%s] a_delay[%0d][%0d] expected 0, got %0d",
                             test_name, i, j, dut.a_delay[i][j]);
                    failed = 1'b1;
                end
                if (dut.b_delay[i][j] !== '0) begin
                    $display("[%s] b_delay[%0d][%0d] expected 0, got %0d",
                             test_name, i, j, dut.b_delay[i][j]);
                    failed = 1'b1;
                end
                if (dut.a_wire[i][j] !== '0) begin
                    $display("[%s] a_wire[%0d][%0d] expected 0, got %0d",
                             test_name, i, j, dut.a_wire[i][j]);
                    failed = 1'b1;
                end
                if (dut.b_wire[i][j] !== '0) begin
                    $display("[%s] b_wire[%0d][%0d] expected 0, got %0d",
                             test_name, i, j, dut.b_wire[i][j]);
                    failed = 1'b1;
                end
                if (dut.pe_valid[i][j] !== 1'b0) begin
                    $display("[%s] pe_valid[%0d][%0d] expected 0, got %0b",
                             test_name, i, j, dut.pe_valid[i][j]);
                    failed = 1'b1;
                end
                if (c[i][j] !== '0) begin
                    $display("[%s] c[%0d][%0d] expected 0, got %0d",
                             test_name, i, j, c[i][j]);
                    failed = 1'b1;
                end
            end
        end

        report_case(test_name, failed);
    endtask

    task automatic check_active_state(input string test_name);
        bit failed;
        failed = 1'b0;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if ($isunknown(dut.a_delay[i][j]) ||
                    dut.a_delay[i][j] === '0) begin
                    $display("[%s] a_delay[%0d][%0d] is not known nonzero",
                             test_name, i, j);
                    failed = 1'b1;
                end
                if ($isunknown(dut.b_delay[i][j]) ||
                    dut.b_delay[i][j] === '0) begin
                    $display("[%s] b_delay[%0d][%0d] is not known nonzero",
                             test_name, i, j);
                    failed = 1'b1;
                end
                if ($isunknown(dut.a_wire[i][j]) ||
                    dut.a_wire[i][j] === '0) begin
                    $display("[%s] a_wire[%0d][%0d] is not known nonzero",
                             test_name, i, j);
                    failed = 1'b1;
                end
                if ($isunknown(dut.b_wire[i][j]) ||
                    dut.b_wire[i][j] === '0) begin
                    $display("[%s] b_wire[%0d][%0d] is not known nonzero",
                             test_name, i, j);
                    failed = 1'b1;
                end
                if (dut.pe_valid[i][j] !== 1'b1) begin
                    $display("[%s] pe_valid[%0d][%0d] expected 1, got %0b",
                             test_name, i, j, dut.pe_valid[i][j]);
                    failed = 1'b1;
                end
                if ($isunknown(c[i][j]) || c[i][j] === '0) begin
                    $display("[%s] c[%0d][%0d] is not known nonzero",
                             test_name, i, j);
                    failed = 1'b1;
                end
            end
        end

        report_case(test_name, failed);
    endtask

    task automatic async_reset(input string test_name);
        clear = 1'b0;
        valid_in = 1'b0;

        @(negedge clk);
        #2;
        rst_n = 1'b0;
        #1;
        check_all_zero(test_name);

        @(negedge clk);
        rst_n = 1'b1;
    endtask

    task automatic create_nonzero_state;
        rst_n = 1'b1;
        clear = 1'b0;

        repeat (2*N) begin
            @(negedge clk);
            valid_in = 1'b1;
            for (int i = 0; i < N; i++)
                a_in[i] = i + 1;
            for (int j = 0; j < N; j++)
                b_in[j] = j + 1;

            @(posedge clk);
            #1;
        end
    endtask

    task automatic test_async_reset_active_priority;
        create_nonzero_state();
        check_active_state("SARR_RST active precondition");

        @(negedge clk);
        #2;
        clear = 1'b1;
        valid_in = 1'b1;
        for (int i = 0; i < N; i++) begin
            a_in[i] = i + 2;
            b_in[i] = i + 3;
        end
        rst_n = 1'b0;
        #1;
        check_all_zero("SARR_RST async active priority");

        for (int hold = 0; hold < 2; hold++) begin
            @(negedge clk);
            clear = ~clear;
            valid_in = ~valid_in;
            for (int i = 0; i < N; i++) begin
                a_in[i] = i + hold + 4;
                b_in[i] = i + hold + 5;
            end
            @(posedge clk);
            #1;
            check_all_zero("SARR_RST hold");
        end

        @(negedge clk);
        clear = 1'b0;
        valid_in = 1'b0;
        rst_n = 1'b1;
    endtask

    task automatic sync_clear(input string test_name);
        @(negedge clk);
        rst_n = 1'b1;
        clear = 1'b1;
        valid_in = 1'b1;
        for (int i = 0; i < N; i++) begin
            a_in[i] = i + 1;
            b_in[i] = i + 1;
        end

        @(posedge clk);
        #1;
        check_all_zero({test_name, " priority"});

        for (int hold = 0; hold < 2; hold++) begin
            @(negedge clk);
            clear = 1'b1;
            valid_in = ~valid_in;
            for (int i = 0; i < N; i++) begin
                a_in[i] = i + hold + 2;
                b_in[i] = i + hold + 3;
            end
            @(posedge clk);
            #1;
            check_all_zero({test_name, " hold"});
        end

        @(negedge clk);
        clear = 1'b0;
        valid_in = 1'b0;
        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end
    endtask

    task automatic apply_clear(input string test_name);
        @(negedge clk);
        rst_n = 1'b1;
        clear = 1'b1;
        valid_in = 1'b0;
        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end

        @(posedge clk);
        #1;
        check_all_zero(test_name);

        @(negedge clk);
        clear = 1'b0;
    endtask

    function automatic acc_t extend_product(
        input logic signed [2*width-1:0] product
    );
        extend_product = {
            {(ACC_WIDTH-2*width){product[2*width-1]}},
            product
        };
    endfunction

    task automatic compute_expected;
        logic signed [2*width-1:0] product;
        acc_t sum;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                sum = '0;
                for (int k = 0; k < N; k++) begin
                    product = matrix_a[i][k] * matrix_b[k][j];
                    sum = sum + extend_product(product);
                end
                expected[i][j] = sum;
            end
        end
    endtask

    task automatic build_identity_test;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                matrix_a[i][j] = (i == j) ? 1 : 0;
                matrix_b[i][j] = i*N + j + 1;
                expected[i][j] = matrix_b[i][j];
            end
        end
    endtask

    task automatic build_signed_test;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                matrix_a[i][j] = ((i + j) % 5) - 2;
                matrix_b[i][j] = ((2*i + j) % 7) - 3;
            end
        end
        compute_expected();
    endtask

    task automatic drive_matrix;
        for (int k = 0; k < N; k++) begin
            @(negedge clk);
            valid_in = 1'b1;
            for (int i = 0; i < N; i++)
                a_in[i] = matrix_a[i][k];
            for (int j = 0; j < N; j++)
                b_in[j] = matrix_b[k][j];

            @(posedge clk);
            #1;
        end

        @(negedge clk);
        valid_in = 1'b0;
        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end
    endtask

    task automatic wait_for_drain;
        repeat (2*N) @(posedge clk);
        #1;
    endtask

    task automatic check_all_valid_low(input string test_name);
        bit failed;
        failed = 1'b0;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (dut.pe_valid[i][j] !== 1'b0) begin
                    $display("[%s] pe_valid[%0d][%0d] expected 0, got %0b",
                             test_name, i, j, dut.pe_valid[i][j]);
                    failed = 1'b1;
                end
            end
        end
        report_case(test_name, failed);
    endtask

    task automatic check_matrix(input string test_name);
        bit failed;
        failed = 1'b0;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (c[i][j] !== expected[i][j]) begin
                    $display("[%s] c[%0d][%0d] expected %0d, got %0d",
                             test_name, i, j, expected[i][j], c[i][j]);
                    failed = 1'b1;
                end
            end
        end

        report_case(test_name, failed);
    endtask

    task automatic check_output_hold(input string test_name);
        bit failed;
        failed = 1'b0;

        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                snapshot[i][j] = c[i][j];

        for (int cycle = 0; cycle < N; cycle++) begin
            @(negedge clk);
            valid_in = 1'b0;
            for (int i = 0; i < N; i++) begin
                a_in[i] = i + cycle + 1;
                b_in[i] = i - cycle - 1;
            end

            @(posedge clk);
            #1;
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    if (c[i][j] !== snapshot[i][j]) begin
                        $display("[%s] c[%0d][%0d] changed: expected %0d, got %0d",
                                 test_name, i, j, snapshot[i][j], c[i][j]);
                        failed = 1'b1;
                    end
                end
            end
        end

        report_case(test_name, failed);
    endtask

    task automatic compute_constant_burst_expected(input int cycles);
        logic signed [2*width-1:0] product;
        acc_t sum;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                product = operand_t'(i + 1) * operand_t'(j + 1);
                sum = '0;
                for (int m = 0; m < cycles; m++)
                    sum = sum + extend_product(product);
                expected[i][j] = sum;
            end
        end
    endtask

    task automatic test_valid_burst(
        input int cycles,
        input string test_name
    );
        apply_clear({test_name, " clear"});
        compute_constant_burst_expected(cycles);

        repeat (cycles) begin
            @(negedge clk);
            valid_in = 1'b1;
            for (int i = 0; i < N; i++) begin
                a_in[i] = i + 1;
                b_in[i] = i + 1;
            end
            @(posedge clk);
            #1;
        end

        @(negedge clk);
        valid_in = 1'b0;
        for (int i = 0; i < N; i++) begin
            a_in[i] = '0;
            b_in[i] = '0;
        end

        wait_for_drain();
        check_all_valid_low({test_name, " drained"});
        check_matrix(test_name);
    endtask

    initial begin
        init_signals();

        async_reset("SARR_RST startup asynchronous");
        test_async_reset_active_priority();

        create_nonzero_state();
        check_active_state("SARR_CLR active precondition");
        sync_clear("SARR_CLR synchronous");

        test_valid_burst(1, "SARR single valid pulse");
        test_valid_burst(N + 1, "SARR non-N valid pulse");

        build_identity_test();
        apply_clear("SARR identity clear");
        drive_matrix();
        wait_for_drain();
        check_all_valid_low("SARR identity drained");
        check_matrix("SARR identity matrix");
        check_output_hold("SARR output hold");

        build_signed_test();
        apply_clear("SARR back-to-back clear");
        drive_matrix();
        wait_for_drain();
        check_all_valid_low("SARR signed drained");
        check_matrix("SARR signed matrix");

        $display("SARR directed summary: pass=%0d fail=%0d",
                 pass_cnt, fail_cnt);
        if (fail_cnt != 0)
            $fatal(1, "SARR directed regression failed");

        $display("SARR directed regression passed");
        $finish;
    end

    initial begin
        if (N < 1)
            $fatal(1, "N must be at least 1");
        if (ACC_WIDTH < 2*width)
            $fatal(1, "ACC_WIDTH must be at least 2*width");
        #(2000*N);
        $fatal(1, "SARR directed regression timeout");
    end

endmodule
