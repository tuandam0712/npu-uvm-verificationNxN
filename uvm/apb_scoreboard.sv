class apb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_sequence_item, apb_scoreboard) analysis_imp;

    int total_cnt;
    int pass_cnt;
    int fail_cnt;

    int c_check_cnt;
    int c_pass_cnt;
    int c_fail_cnt;

    int signed a_mem [APB_N * APB_N];
    int signed b_mem [APB_N * APB_N];

    function new(string name = "apb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        analysis_imp = new("analysis_imp", this);

        total_cnt   = 0;
        pass_cnt    = 0;
        fail_cnt    = 0;

        c_check_cnt = 0;
        c_pass_cnt  = 0;
        c_fail_cnt  = 0;

        for (int i = 0; i < APB_N * APB_N; i++) begin
            a_mem[i] = 0;
            b_mem[i] = 0;
        end
    endfunction

    function bit is_a_addr(bit [31:0] addr);
        return ((addr >= APB_A_BASE) &&
                (addr <  APB_A_BASE + APB_N * APB_N * APB_WORD_BYTES));
    endfunction

    function bit is_b_addr(bit [31:0] addr);
        return ((addr >= APB_B_BASE) &&
                (addr <  APB_B_BASE + APB_N * APB_N * APB_WORD_BYTES));
    endfunction

    function bit is_c_addr(bit [31:0] addr);
        return ((addr >= APB_C_BASE) &&
                (addr <  APB_C_BASE + APB_N * APB_N * APB_WORD_BYTES));
    endfunction

    function int get_a_index(bit [31:0] addr);
        return (addr - APB_A_BASE) >> 2;
    endfunction

    function int get_b_index(bit [31:0] addr);
        return (addr - APB_B_BASE) >> 2;
    endfunction

    function int get_c_index(bit [31:0] addr);
        return (addr - APB_C_BASE) >> 2;
    endfunction

    function int signed sign_extend_data(bit [31:0] data);
        bit signed [APB_DATA_WIDTH-1:0] tmp;
        tmp = data[APB_DATA_WIDTH-1:0];
        return tmp;
    endfunction

    function int signed expected_c_value(int c_index);
        int row;
        int col;
        int signed sum;

        row = c_index / APB_N;
        col = c_index % APB_N;
        sum = 0;

        for (int k = 0; k < APB_N; k++) begin
            sum += a_mem[row * APB_N + k] * b_mem[k * APB_N + col];
        end

        return sum;
    endfunction

    function void write(apb_sequence_item item);
        int index;
        int signed expected;
        int signed actual;

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

        // Capture A/B writes into scoreboard memory model
        if (item.write == 1'b1 && is_a_addr(item.addr)) begin
            index = get_a_index(item.addr);
            a_mem[index] = sign_extend_data(item.wdata);

            `uvm_info("APB_SCB",
                $sformatf("A model update index=%0d value=%0d",
                          index, a_mem[index]),
                UVM_HIGH)
        end
        else if (item.write == 1'b1 && is_b_addr(item.addr)) begin
            index = get_b_index(item.addr);
            b_mem[index] = sign_extend_data(item.wdata);

            `uvm_info("APB_SCB",
                $sformatf("B model update index=%0d value=%0d",
                          index, b_mem[index]),
                UVM_HIGH)
        end

        // Check C reads against dynamic golden model
        if (item.write == 1'b0 && is_c_addr(item.addr)) begin
            index    = get_c_index(item.addr);
            expected = expected_c_value(index);
            actual   = $signed(item.rdata);

            c_check_cnt++;

            if (actual !== expected) begin
                fail_cnt++;
                c_fail_cnt++;

                `uvm_error("APB_SCB",
                    $sformatf("C mismatch index=%0d addr=0x%08h expected=%0d actual=%0d rdata=0x%08h",
                              index,
                              item.addr,
                              expected,
                              actual,
                              item.rdata))
                return;
            end
            else begin
                c_pass_cnt++;

                `uvm_info("APB_SCB",
                    $sformatf("C PASS index=%0d expected=%0d actual=%0d",
                              index, expected, actual),
                    UVM_HIGH)
            end
        end

        pass_cnt++;

        `uvm_info("APB_SCB",
            $sformatf("PASS %s addr=0x%08h wdata=0x%08h rdata=0x%08h",
                      item.write ? "WRITE" : "READ ",
                      item.addr,
                      item.wdata,
                      item.rdata),
            UVM_HIGH)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("APB_SCB",
            $sformatf("APB SCOREBOARD SUMMARY: total=%0d pass=%0d fail=%0d",
                      total_cnt, pass_cnt, fail_cnt),
            UVM_LOW)

        `uvm_info("APB_SCB",
            $sformatf("C MATRIX CHECK SUMMARY: checked=%0d pass=%0d fail=%0d",
                      c_check_cnt, c_pass_cnt, c_fail_cnt),
            UVM_LOW)

        if (fail_cnt == 0 && total_cnt > 0 && c_check_cnt >0 && c_fail_cnt == 0) begin
            `uvm_info("APB_SCB", "APB SCOREBOARD PASS", UVM_LOW)
        end
        else begin
            `uvm_error("APB_SCB", "APB SCOREBOARD FAIL")
        end
    endfunction

endclass
