`timescale 1ns/1ps

import uvm_pkg::*;
import npu_pkg::*;
`include "uvm_macros.svh"
module tb_npu_nxn;
    parameter N = 8;
    parameter width = 8;
    
    logic clk, rst_n;
    npu_if #(.N(N), .width(width)) vif(.clk(clk));
    
    npu_top_NXN #(.N(N), .width(width)) dut(
        .clk(clk),
        .rst_n(vif.rst_n),
        .start(vif.start),
        .a_in(vif.a),
        .b_in(vif.b),
        .done(vif.done),
        .c(vif.c),
        .valid_in(vif.valid_in) 
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        vif.rst_n = 0;
        vif.start = 0;

        if ($test$plusargs("RESET_DURING_COMPUTE") &&
            $test$plusargs("RESET_DURING_DRAIN")) begin
            `uvm_fatal("RESET_CONFIG", "Select only one reset scenario per run")
        end

        repeat (10) @(posedge clk);
        @(negedge clk);
        vif.rst_n = 1;

        if ($test$plusargs("RESET_DURING_DRAIN") ||
            $test$plusargs("RESET_DURING_COMPUTE")) begin
            wait(vif.valid_in === 1'b1);
            if ($test$plusargs("RESET_DURING_COMPUTE")) begin
                if (N < 2) begin
                    `uvm_fatal("RESET_CONFIG", "Partial-feed reset requires N >= 2")
                end
                // Interrupt after half the input slices, before the full matrix.
                repeat (N/2) @(posedge clk);
                @(negedge clk);
                if (vif.valid_in !== 1'b1 || vif.done !== 1'b0) begin
                    `uvm_fatal("RESET_PHASE", "Expected COMPUTE with valid_in high")
                end
                $display("[RESET_TEST] Assert reset during compute after %0d slices", N/2);
            end else begin
                @(negedge vif.valid_in);
                @(negedge clk);
                if (vif.valid_in !== 1'b0 || vif.done !== 1'b0) begin
                    `uvm_fatal("RESET_PHASE", "Expected drain interval before done")
                end
                $display("[RESET_TEST] Assert reset during drain");
            end
            vif.rst_n = 1'b0;

            repeat (3) begin
                @(posedge clk);
                #1; // Check after sequential reset updates have settled.
                if (vif.done !== 1'b0 || vif.valid_in !== 1'b0) begin
                    `uvm_error("RESET_STATE", "done/valid_in must be zero during reset")
                end
                for (int i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        if (vif.c[i][j] !== '0) begin
                            `uvm_error("RESET_STATE",
                                $sformatf("C[%0d][%0d] is not zero during reset", i, j))
                        end
                    end
                end
                @(negedge clk);
            end
            vif.rst_n = 1'b1;
            $display("[RESET_TEST] Release reset");
        end
    end
    
    initial begin
        uvm_config_db #(virtual npu_if #(N, width))::set(null, "*", "vif", vif);
        run_test("npu_test_N8");
    end
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_npu_nxn);
    end
endmodule
