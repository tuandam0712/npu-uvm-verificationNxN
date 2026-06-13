class npu_coverage #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_subscriber #(npu_sequence_item #(N, width));
    `uvm_component_param_utils(npu_coverage #(N, width))
    typedef npu_sequence_item #(N, width) item_t;
    typedef enum int{
        MATRIX_ZERO,
        MATRIX_IDENTITY,
        MATRIX_RANDOM,
        MATRIX_OTHER,
        ALL_POSITIVE,
        ALL_NEGATIVE,
        SPARSE
    } matrix_type_e;
    matrix_type_e sample_matrix_type;
    int signed sample_a;
    int signed sample_b;
    covergroup cg_input_data;
        option.per_instance = 1;

        cp_a_value: coverpoint sample_a {
            bins zero     = {0};
            bins min_negative = {-64};
            bins max_positive = {63};
            bins positive = {[1:62]};
            bins negative = {[-63:-1]};
        }

        cp_b_value: coverpoint sample_b {
            bins zero     = {0};
            bins min_negative = {-64};
            bins max_positive = {63};
            bins positive = {[1:62]};
            bins negative = {[-63:-1]};
        }

        cross_a_b_value: cross cp_a_value, cp_b_value;
    endgroup
    covergroup cg_matrix_pattern;
        option.per_instance = 1;
        cp_matrix_type: coverpoint sample_matrix_type{
            bins zero = {MATRIX_ZERO};
            bins identity = {MATRIX_IDENTITY};
            bins random = {MATRIX_RANDOM};
            bins all_positive = {ALL_POSITIVE};
            bins all_negative = {ALL_NEGATIVE};
            bins sparse = {SPARSE};
            ignore_bins ignore_other = {MATRIX_OTHER};
        }
    endgroup
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_input_data = new();
        cg_matrix_pattern = new();
    endfunction
    function bit is_zero_matrix(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if(t.a[i][j] != 0) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_identity_matrix(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (i == j) begin
                    if (t.a[i][j] != 1) return 0;
                end
                else begin
                    if (t.a[i][j] != 0) return 0;
                end
            end
        end
        return 1;
    endfunction
    function bit is_all_positive(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if(t.a[i][j] != 63) return 0;
                if(t.b[i][j] != 63) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_all_negative(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if(t.a[i][j] != -64) return 0;
                if(t.b[i][j] != -64) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_sparse(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if(i == j) begin
                    if(t.a[i][j] != 5) return 0;
                    if(t.b[i][j] != -2) return 0;
                end
                else begin
                    if(t.a[i][j] != 0) return 0;
                    if(t.b[i][j] != 0) return 0;
                end
            end
        end
        return 1;
    endfunction
    virtual function void write(item_t t);
        if(is_zero_matrix(t)) sample_matrix_type = MATRIX_ZERO;
        else if(is_identity_matrix(t)) sample_matrix_type = MATRIX_IDENTITY;
        else if(is_all_positive(t)) sample_matrix_type = ALL_POSITIVE;
        else if(is_all_negative(t)) sample_matrix_type = ALL_NEGATIVE;
        else if(is_sparse(t)) sample_matrix_type = SPARSE;
        else sample_matrix_type = MATRIX_RANDOM;
        cg_matrix_pattern.sample();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                sample_a = t.a[i][j];
                sample_b = t.b[i][j];
                cg_input_data.sample();
            end
        end
    endfunction
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV",$sformatf("in data cov = %.2f%%, mat pattern cov = %.2f%%", cg_input_data.get_coverage(), cg_matrix_pattern.get_coverage()), UVM_LOW)
    endfunction
endclass
class npu_output_coverage #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_subscriber #(npu_sequence_item #(N, width));

    `uvm_component_param_utils(npu_output_coverage #(N, width))

    typedef npu_sequence_item #(N, width) item_t;

    localparam int ACC_WIDTH = 2*width + $clog2(N);

    int signed sample_c;

    covergroup cg_output_data;
        option.per_instance = 1;

        cp_c_value: coverpoint sample_c {
            bins zero     = {0};
            bins large_negative = {[-32768:-101]};
            bins large_positive = {[101:32767]};
            bins small_negative = {[-100:-1]};
            bins small_positive = {[1:100]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_output_data = new();
    endfunction

    virtual function void write(item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                sample_c = t.act[i][j];
                cg_output_data.sample();
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV_OUT",
            $sformatf("output data coverage = %.2f%%",
                      cg_output_data.get_coverage()),
            UVM_LOW)
    endfunction

endclass