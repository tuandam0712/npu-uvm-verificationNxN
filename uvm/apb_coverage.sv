class apb_coverage extends uvm_subscriber #(apb_sequence_item);

    `uvm_component_utils(apb_coverage)

    bit        is_write;
    bit [31:0] addr;
    bit        slverr;
    int sample_cnt;
    int start_write_cnt;
    int status_read_cnt;
    int c_read_cnt;
    int busy_seen;
    int done_seen;
    int slverr_seen;
    covergroup cg_apb;

        cp_rw: coverpoint is_write {
            bins read  = {0};
            bins write = {1};
        }

        cp_addr: coverpoint addr {
            bins control = {32'h0000_0000};
            bins status  = {32'h0000_0004};
            bins a_region = {[32'h0000_0010 : 32'h0000_010C]};
            bins b_region = {[32'h0000_0110 : 32'h0000_020C]};
            bins c_region = {[32'h0000_0210 : 32'h0000_030C]};
            bins other   = default;
        }

        cp_slverr: coverpoint slverr {
            bins no_error = {0};
            ignore_bins error    = {1};
        }

        cross_rw_addr: cross cp_rw, cp_addr;

    endgroup

    function new(string name = "apb_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_apb = new();
    endfunction

    function void write(apb_sequence_item t);
        is_write = t.write;
        addr     = t.addr;
        slverr   = t.slverr;

        // Count every APB transaction sampled by coverage
        sample_cnt++;

        // CONTROL.start write
        if (t.write && t.addr == 32'h0000_0000 && t.wdata[0]) begin
            start_write_cnt++;
        end

        // STATUS read
        if (!t.write && t.addr == 32'h0000_0004) begin
            status_read_cnt++;

            // STATUS[1] = busy
            if (t.rdata[1]) begin
                busy_seen++;
            end

            // STATUS[0] = done
            if (t.rdata[0]) begin
                done_seen++;
            end
        end

        // C matrix read region: C_BASE = 0x210, 8x8 words, each word = 4 bytes
        if (!t.write &&
            t.addr >= 32'h0000_0210 &&
            t.addr <  32'h0000_0210 + 8 * 8 * 4) begin
            c_read_cnt++;
        end

        // Slave error seen
        if (t.slverr) begin
            slverr_seen++;
        end

        cg_apb.sample();

        `uvm_info("APB_COV",
            $sformatf("Sample APB coverage: %s addr=0x%08h slverr=%0b cov=%.2f%%",
                    t.write ? "WRITE" : "READ ",
                    t.addr,
                    t.slverr,
                    cg_apb.get_coverage()),
            UVM_HIGH)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("APB_COV",
            $sformatf("APB COVERAGE = %0.2f%%",
                    cg_apb.get_coverage()),
            UVM_LOW)

        `uvm_info("APB_COV",
            $sformatf("APB COVERAGE SUMMARY: samples=%0d start_writes=%0d status_reads=%0d c_reads=%0d",
                    sample_cnt, start_write_cnt, status_read_cnt, c_read_cnt),
            UVM_LOW)

        `uvm_info("APB_COV",
            $sformatf("APB STATUS SUMMARY: busy_seen=%0d done_seen=%0d slverr_seen=%0d",
                    busy_seen, done_seen, slverr_seen),
            UVM_LOW)
    endfunction

endclass