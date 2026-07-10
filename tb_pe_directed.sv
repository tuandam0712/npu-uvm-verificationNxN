`timescale 1ns/1ps
module tb_pe_directed;

    parameter int width = 8;
    parameter int N = 8;
    parameter int ACC_WIDTH = 2*width +((N>1) ? $clog2(N) : 1);
    logic clk;
    logic rst_n;
    logic clear;
    logic valid;
    logic signed [width-1:0] a_in;
    logic signed [width-1:0] b_in;
    logic signed [ACC_WIDTH-1:0] acc;
    int pass_cnt;
    int fail_cnt;
    pe #(
        .width(width),
        .N(N),
        .ACC_WIDTH(ACC_WIDTH),
        .ROW(0),
        .COL(0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .valid(valid),
        .a_in(a_in),
        .b_in(b_in),
        .acc(acc)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    task automatic check_acc(
        input logic signed [ACC_WIDTH-1:0] exp,
        input string test_name
    );
        if(acc !== exp) begin
            $display("[%0t] Test %s failed: expected %0d, got %0d", $time, test_name, exp, acc);
            fail_cnt++;
        end else begin
            $display("[%0t] Test %s passed: expected %0d, got %0d", $time, test_name, exp, acc);
            pass_cnt++;
        end
    endtask
    task automatic reset_pe();
        rst_n = 0;
        clear = 0;
        valid = 0;
        a_in = 0;
        b_in = 0;
        #2;
        check_acc(0, "Reset");
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
    endtask
    task automatic test_async_reset_between_edges();
        reset_pe();
        @(negedge clk);
        valid = 1;
        a_in = 3;
        b_in = 4;
        @(posedge clk);
        #1;
        check_acc(12, "Async Reset Between Edges after MAC");
        @(negedge clk);
        valid = 0;
        #2;
        rst_n = 0;
        #1;
        check_acc(0, "Async Reset Between Edges after reset");
        rst_n = 1;
    endtask
    task automatic test_reset_priority();
        reset_pe();
        @(negedge clk);
        rst_n = 0;
        clear = 1;
        valid = 1;
        a_in = 5;
        b_in = 6;
        @(posedge clk);
        #1;
        check_acc(0, "Reset Priority");
        rst_n = 1;
        clear = 0;
        valid = 0;
    endtask
    task automatic test_clear_priority();
        reset_pe();
        @(negedge clk);
        valid = 1;
        clear = 0;
        a_in = 7;
        b_in = 8;
        @(posedge clk);
        #1;
        check_acc(56, "Clear Priority before Clear");
        @(negedge clk);
        clear = 1;
        valid = 1;
        a_in = 9;
        b_in = 10;
        @(posedge clk);
        #1;
        check_acc(0, "Clear Priority after Clear");
        clear = 0;
        valid = 0;
    endtask
    task automatic test_hold_after_mac();
        reset_pe();
        @(negedge clk);
        valid = 1;
        clear = 0;
        a_in = -11;
        b_in = 12;
        @(posedge clk);
        #1;
        check_acc(-132, "Hold After MAC initial");
        @(negedge clk);
        valid = 0;
        a_in = 13;
        b_in = 14;
        @(posedge clk);
        #1;
        check_acc(-132, "Hold After MAC hold");
    endtask
    task automatic test_signed_comb();
        reset_pe();
        @(negedge clk);
        valid = 1;
        a_in = 15;
        b_in = 16;
        @(posedge clk);
        #1;
        check_acc(240, "Signed Combination 15*16");
        @(negedge clk);
        a_in = -17;
        b_in = 18;
        @(posedge clk);
        #1;
        check_acc(-66, "Signed Combination -17*18");
        @(negedge clk);
        a_in = 19;
        b_in = -20;
        @(posedge clk);
        #1;
        check_acc(-446, "Signed Combination 19*-20");
        @(negedge clk);
        a_in = -21;
        b_in = -22;
        @(posedge clk);
        #1;
        check_acc(16, "Signed Combination -21*-22");
        valid = 0;
    endtask
    task automatic test_most_neg();
        logic signed [width-1:0] min_val;
        logic signed [ACC_WIDTH-1:0] exp;

        min_val = {1'b1, {(width-1){1'b0}}};
        exp = (1 <<< (width-1));

        reset_pe();

        @(negedge clk);
        valid = 1;
        a_in = min_val;
        b_in = -1;

        @(posedge clk);
        #1;
        check_acc(exp, "Most Negative Value");

        valid = 0;
    endtask
    function automatic logic signed [ACC_WIDTH-1:0] wrap_add(
        input logic signed [ACC_WIDTH-1:0] lhs,
        input logic signed [2*width-1:0] rhs
    );
        logic signed [ACC_WIDTH-1:0] rsh_ext;
        rsh_ext = {{ACC_WIDTH-2*width{rhs[2*width-1]}}, rhs};
        return lhs + rsh_ext;
    endfunction
    task automatic test_wrap();
        logic signed [ACC_WIDTH-1:0] exp;
        logic signed [2*width-1:0] prd;
        reset_pe();
        exp = '0;
        valid = 1;
        clear = 0;
        a_in = {1'b0, {(width-1){1'b1}}};
        b_in = {1'b0, {(width-1){1'b1}}};
        for (int i = 0; i < 20; i++) begin
            prd = a_in * b_in;

            @(posedge clk);
            #1;

            exp = wrap_add(exp, prd);
            check_acc(exp, $sformatf("Wrap Test %0d", i));
        end
        valid = 0;
    endtask
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        rst_n = 1;
        clear = 0;
        valid = 0;
        a_in = 0;
        b_in = 0;
        test_async_reset_between_edges();
        test_reset_priority();
        test_clear_priority();
        test_hold_after_mac();
        test_signed_comb();
        test_most_neg();
        test_wrap();
        $display("Total tests passed: %0d", pass_cnt);
        if (fail_cnt != 0) begin
            $fatal(1, "Total tests failed: %0d", fail_cnt);
        end
        $finish;
    end
endmodule