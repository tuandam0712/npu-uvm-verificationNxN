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
        repeat(10) @(posedge clk);
        vif.rst_n = 1;
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