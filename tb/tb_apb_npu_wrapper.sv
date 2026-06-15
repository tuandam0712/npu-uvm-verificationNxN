module tb_apb_npu_wrapper;

    import uvm_pkg::*;
    import apb_pkg::*;

    `include "uvm_macros.svh"

    logic pclk;

    // clock
    initial begin
        pclk = 1'b0;
        forever #5 pclk = ~pclk;
    end

    // APB interface
    apb_if apb_vif(pclk);

    // reset
    initial begin
        apb_vif.presetn = 1'b0;
        repeat (5) @(posedge pclk);
        apb_vif.presetn = 1'b1;
    end

    // DUT
    apb_npu_wrapper dut (
        .pclk    (pclk),
        .presetn (apb_vif.presetn),
        .psel    (apb_vif.psel),
        .penable (apb_vif.penable),
        .pwrite  (apb_vif.pwrite),
        .paddr   (apb_vif.paddr),
        .pwdata  (apb_vif.pwdata),
        .prdata  (apb_vif.prdata),
        .pready  (apb_vif.pready),
        .pslverr (apb_vif.pslverr)
    );

    initial begin
        uvm_config_db #(virtual apb_if)::set(
            null,
            "uvm_test_top.env.agent.*",
            "vif",
            apb_vif
        );

        run_test("apb_test");
    end

endmodule