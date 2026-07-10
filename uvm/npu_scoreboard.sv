class npu_scoreboard #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_scoreboard;
    `uvm_component_param_utils(npu_scoreboard #(N, width))

    typedef npu_sequence_item #(N, width) item_t;
    localparam int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1);

    typedef logic signed [ACC_WIDTH-1:0] acc_t;

    function automatic acc_t cast_to_acc_width(longint signed value);
        cast_to_acc_width = acc_t'(value);
    endfunction

    uvm_tlm_analysis_fifo #(item_t) in_fifo;
    uvm_tlm_analysis_fifo #(item_t) out_fifo;

    uvm_analysis_export #(item_t) in_export;
    uvm_analysis_export #(item_t) out_export;

    int pass_count;
    int fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pass_count = 0;
        fail_count = 0;

        in_fifo    = new("in_fifo", this);
        out_fifo   = new("out_fifo", this);
        in_export  = new("in_export", this);
        out_export = new("out_export", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        in_export.connect(in_fifo.analysis_export);
        out_export.connect(out_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        item_t exp_item;
        item_t act_item;
        longint signed golden_full [N-1:0][N-1:0];
        acc_t golden_hw [N-1:0][N-1:0];
        int errors;

        forever begin
            in_fifo.get(exp_item);
            out_fifo.get(act_item);

            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    golden_full[i][j] = 0;

                    for (int k = 0; k < N; k++) begin
                        golden_full[i][j] += longint'(exp_item.a[i][k]) * longint'(exp_item.b[k][j]);
                    end

                    golden_hw[i][j] = cast_to_acc_width(golden_full[i][j]);
                    exp_item.exp[i][j] = golden_hw[i][j];
                end
            end

            errors = 0;
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    if (acc_t'(act_item.act[i][j]) != golden_hw[i][j]) begin
                        errors++;
                        `uvm_error("SCB_MISMATCH", $sformatf(
                            "[%0d][%0d] act=%0d exp_hw=%0d exp_full=%0d diff_hw=%0d",
                            i, j,
                            acc_t'(act_item.act[i][j]),
                            golden_hw[i][j],
                            golden_full[i][j],
                            acc_t'(act_item.act[i][j]) - golden_hw[i][j]))
                    end
                end
            end

            if (errors == 0) begin
                pass_count++;
                `uvm_info("SCB_PASS", $sformatf("match trans=%0d", pass_count), UVM_MEDIUM)
            end else begin
                fail_count++;
                `uvm_error("SCB_FAIL", $sformatf("mismatch! err=%0d total_fail=%0d", errors, fail_count))
            end
        end
    endtask
endclass
