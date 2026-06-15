class apb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_sequence_item, apb_scoreboard) analysis_imp;

    int total_cnt;
    int pass_cnt;
    int fail_cnt;

    function new(string name = "apb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        analysis_imp = new("analysis_imp", this);

        total_cnt = 0;
        pass_cnt  = 0;
        fail_cnt  = 0;
    endfunction

    function void write(apb_sequence_item item);
        total_cnt++;

        if (item.slverr !== 1'b0) begin
            fail_cnt++;
            `uvm_error("APB_SCB",
                $sformatf("Unexpected SLVERR addr=0x%08h write=%0b",
                          item.addr, item.write))
            return;
        end

        if (item.write == 1'b0) begin
            if (^item.rdata === 1'bx) begin
                fail_cnt++;
                `uvm_error("APB_SCB",
                    $sformatf("READ data has X addr=0x%08h rdata=0x%08h",
                              item.addr, item.rdata))
                return;
            end
        end

        pass_cnt++;

        `uvm_info("APB_SCB",
            $sformatf("PASS %s addr=0x%08h wdata=0x%08h rdata=0x%08h",
                      item.write ? "WRITE" : "READ ",
                      item.addr,
                      item.wdata,
                      item.rdata),
            UVM_LOW)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("APB_SCB",
            $sformatf("APB SCOREBOARD SUMMARY: total=%0d pass=%0d fail=%0d",
                      total_cnt, pass_cnt, fail_cnt),
            UVM_LOW)

        if (fail_cnt == 0 && total_cnt > 0) begin
            `uvm_info("APB_SCB", "APB SCOREBOARD PASS", UVM_LOW)
        end
        else begin
            `uvm_error("APB_SCB", "APB SCOREBOARD FAIL")
        end
    endfunction

endclass