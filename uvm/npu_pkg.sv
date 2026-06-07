package npu_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    parameter int N = 8;
    parameter int WIDTH = 8;
    typedef virtual npu_if #(N, WIDTH) vif_t;
    `include "npu_sequence_item.sv"
    `include "npu_sequence.sv"
    `include "npu_sequencer.sv"
    `include "npu_driver.sv"
    `include "npu_monitor.sv"
    `include "npu_agent.sv"
    `include "npu_scoreboard.sv"
    `include "npu_env.sv"
    `include "npu_test.sv"
    `include "npu_test_wrapper.sv"
endpackage