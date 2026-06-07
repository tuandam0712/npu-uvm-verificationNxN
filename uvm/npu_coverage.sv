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
        MATRIX_OTHER
    } matrix_type_e;
    matrix_type_e sample_matrix_type;
    int signed sample_a;
    int signed sample_b;
    covergroup cg_input_data;
        option.per_instance = 1;

        cp_a_value: coverpoint sample_a {
            bins zero     = {0};
            bins positive = {[1:63]};
            bins negative = {[-64:-1]};
        }

        cp_b_value: coverpoint sample_b {
            bins zero     = {0};
            bins positive = {[1:63]};
            bins negative = {[-64:-1]};
        }

        cross_a_b_sign: cross cp_a_value, cp_b_value;
    endgroup
    covergroup cg_matrix_pattern;
        option.per_instance = 1;
        cp_matrix_type: coverpoint sample_matrix_type{
            bins zero = {MATRIX_ZERO};
            bins indentity = {MATRIX_IDENTITY};
            bins random = {MATRIX_RANDOM};
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
    virtual function void write(item_t t);
        if(is_zero_matrix(t)) sample_matrix_type = MATRIX_ZERO;
        else if(is_identity_matrix(t)) sample_matrix_type = MATRIX_IDENTITY;
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