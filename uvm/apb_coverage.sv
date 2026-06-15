class apb_coverage extends uvm_subscriber #(apb_sequence_item);

    `uvm_component_utils(apb_coverage)

    bit        is_write;
    bit [31:0] addr;
    bit        slverr;

    covergroup cg_apb;

        cp_rw: coverpoint is_write {
            bins read  = {0};
            bins write = {1};
        }

        cp_addr: coverpoint addr {
            bins control = {32'h0000_0000};
            bins status  = {32'h0000_0004};
            bins a_base  = {32'h0000_0010};
            bins b_base  = {32'h0000_0040};
            bins c_base  = {32'h0000_0080};
            bins other   = default;
        }

        cp_slverr: coverpoint slverr {
            bins no_error = {0};
            bins error    = {1};
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
            $sformatf("APB COVERAGE = %.2f%%", cg_apb.get_coverage()),
            UVM_LOW)
    endfunction

endclass