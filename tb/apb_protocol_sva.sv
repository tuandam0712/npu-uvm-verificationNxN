module apb_protocol_sva (
    input logic        pclk,
    input logic        presetn,
    input logic        psel,
    input logic        penable,
    input logic        pwrite,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pready
);

    // PENABLE should only be high when PSEL is high
    property penable_requires_psel;
        @(posedge pclk) disable iff (!presetn)
        penable |-> psel;
    endproperty

    assert property (penable_requires_psel)
        else $error("APB protocol error: PENABLE high while PSEL low");

    // Access phase must follow setup phase
    property access_after_setup;
        @(posedge pclk) disable iff (!presetn)
        (psel && !penable) |=> (psel && penable);
    endproperty

    assert property (access_after_setup)
        else $error("APB protocol error: access phase did not follow setup phase");

    // Address must stay stable during wait states
    property addr_stable_during_wait;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && !pready) |=> $stable(paddr);
    endproperty

    assert property (addr_stable_during_wait)
        else $error("APB protocol error: PADDR changed during wait state");

    // Write data must stay stable during write wait states
    property wdata_stable_during_wait;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pwrite && !pready) |=> $stable(pwdata);
    endproperty

    assert property (wdata_stable_during_wait)
        else $error("APB protocol error: PWDATA changed during write wait state");

    // PWRITE must stay stable during wait states
    property pwrite_stable_during_wait;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && !pready) |=> $stable(pwrite);
    endproperty

    assert property (pwrite_stable_during_wait)
        else $error("APB protocol error: PWRITE changed during wait state");
    property exit_access_after_completion;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pready) |=> !penable;
    endproperty
    assert property (exit_access_after_completion)
        else $error("APB: penable must drop after transfer completion");
    int unsigned b2b_cnt = 0;
    cover property (
        @(posedge pclk) disable iff (!presetn)
        (psel && penable && pready && pwrite)
        ##1 (psel && !penable && pwrite)
        ##1 (psel && penable && pready && pwrite)
    ) begin
        b2b_cnt++;
        $display("[APB_B2B_COV] 2 btb write observed");
    end
    final begin
        $display("[APB_B2B_COV] hits=%0d", b2b_cnt);
    end
endmodule