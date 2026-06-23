class npu_coverage #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_subscriber #(npu_sequence_item #(N, width));
    `uvm_component_param_utils(npu_coverage #(N, width))
    typedef npu_sequence_item #(N, width) item_t;
    typedef enum int{
        MATRIX_ZERO,
        MATRIX_IDENTITY,
        MATRIX_MIN_MAX,
        ALL_POSITIVE,
        ALL_NEGATIVE,
        SPARSE,
        NON_DIAGONAL_SPARSE,
        ROW_ZERO,
        COL_ZERO,
        ALTERNATING_SIGN,
        SINGLE_IMPULSE,
        FULL_INT8_BOUNDARY,
        MATRIX_RANDOM,
        MATRIX_OTHER
    } matrix_type_e;
    localparam int SIGNED_MIN = -(1 << (width-1));
    localparam int SIGNED_MAX =  (1 << (width-1)) - 1;
    localparam int SAFE_MIN   = (SIGNED_MIN < -64) ? -64 : SIGNED_MIN;
    localparam int SAFE_MAX   = (SIGNED_MAX >  63) ?  63 : SIGNED_MAX;
    matrix_type_e sample_matrix_type;
    item_t::scenario_e sample_scenario;
    int signed sample_a;
    int signed sample_b;
    covergroup cg_input_data;
        option.per_instance = 1;

        cp_a_value: coverpoint sample_a {
            bins signed_min       = {SIGNED_MIN};
            bins near_signed_min  = {SIGNED_MIN + 1};
            bins negative_ext     = {[SIGNED_MIN + 2:SAFE_MIN - 1]};
            bins safe_negative    = {[SAFE_MIN:-2]};
            bins minus_one        = {-1};
            bins zero             = {0};
            bins plus_one         = {1};
            bins safe_positive    = {[2:SAFE_MAX]};
            bins positive_ext     = {[SAFE_MAX + 1:SIGNED_MAX - 2]};
            bins near_signed_max  = {SIGNED_MAX - 1};
            bins signed_max       = {SIGNED_MAX};
        }

        cp_b_value: coverpoint sample_b {
            bins signed_min       = {SIGNED_MIN};
            bins near_signed_min  = {SIGNED_MIN + 1};
            bins negative_ext     = {[SIGNED_MIN + 2:SAFE_MIN - 1]};
            bins safe_negative    = {[SAFE_MIN:-2]};
            bins minus_one        = {-1};
            bins zero             = {0};
            bins plus_one         = {1};
            bins safe_positive    = {[2:SAFE_MAX]};
            bins positive_ext     = {[SAFE_MAX + 1:SIGNED_MAX - 2]};
            bins near_signed_max  = {SIGNED_MAX - 1};
            bins signed_max       = {SIGNED_MAX};
        }

        cross_a_b_value: cross cp_a_value, cp_b_value;
    endgroup
    covergroup cg_matrix_pattern;
        option.per_instance = 1;
        cp_matrix_type: coverpoint sample_matrix_type{
            bins zero = {MATRIX_ZERO};
            bins identity = {MATRIX_IDENTITY};
            bins min_max = {MATRIX_MIN_MAX};
            bins all_positive = {ALL_POSITIVE};
            bins all_negative = {ALL_NEGATIVE};
            bins sparse = {SPARSE};
            bins non_diagonal_sparse = {NON_DIAGONAL_SPARSE};
            bins row_zero = {ROW_ZERO};
            bins col_zero = {COL_ZERO};
            bins alternating_sign = {ALTERNATING_SIGN};
            bins single_impulse = {SINGLE_IMPULSE};
            bins full_int8_boundary = {FULL_INT8_BOUNDARY};
            bins random = {MATRIX_RANDOM};
            ignore_bins ignore_other = {MATRIX_OTHER};
        }
    endgroup
    covergroup cg_scenario;
        option.per_instance = 1;

        cp_scenario: coverpoint sample_scenario {
            bins normal       = {item_t::SCENARIO_NORMAL};
            bins back_to_back = {item_t::SCENARIO_BACK_TO_BACK};
        }
    endgroup
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_input_data = new();
        cg_matrix_pattern = new();
        cg_scenario = new();
    endfunction
    function automatic int signed boundary_value(int idx);
        case (idx % 7)
            0: boundary_value = SIGNED_MIN;
            1: boundary_value = SIGNED_MIN + 1;
            2: boundary_value = -1;
            3: boundary_value = 0;
            4: boundary_value = 1;
            5: boundary_value = SIGNED_MAX - 1;
            default: boundary_value = SIGNED_MAX;
        endcase
    endfunction
    function bit is_zero_matrix(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if(t.a[i][j] != 0) return 0;
                if(t.b[i][j] != 0) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_identity_matrix(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (i == j) begin
                    if (t.a[i][j] != 1) return 0;
                    if (t.b[i][j] != 1) return 0;
                end
                else begin
                    if (t.a[i][j] != 0) return 0;
                    if (t.b[i][j] != 0) return 0;
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
    function bit is_min_max(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (t.a[i][j] != ((i < N/2) ? -64 : 63)) return 0;
                if (t.b[i][j] != ((j == 0) ? 0 : ((j < N/2) ? -64 : 63))) return 0;
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
    function bit is_non_diagonal_sparse(input item_t t);
        int col_one;
        int col_prev;
        int mid_next;

        col_one  = (N > 1) ? 1 : 0;
        col_prev = (N > 1) ? N-2 : 0;
        mid_next = (N/2 + 1) % N;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                bit expect_a_nz;
                bit expect_b_nz;
                int signed expect_a;
                int signed expect_b;

                expect_a_nz = ((i == 0 && j == N-1) ||
                               (i == N-1 && j == 0) ||
                               (i == N/2 && j == mid_next));
                expect_b_nz = ((i == N-1 && j == col_one) ||
                               (i == 0 && j == col_prev) ||
                               (i == mid_next && j == N/2));
                expect_a = 0;
                expect_b = 0;
                if (i == 0 && j == N-1) expect_a = 6;
                if (i == N-1 && j == 0) expect_a = -3;
                if (i == N/2 && j == mid_next) expect_a = 2;
                if (i == N-1 && j == col_one) expect_b = -5;
                if (i == 0 && j == col_prev) expect_b = 4;
                if (i == mid_next && j == N/2) expect_b = 7;

                if (expect_a_nz) begin
                    if (t.a[i][j] != expect_a) return 0;
                end else if (t.a[i][j] != 0) return 0;

                if (expect_b_nz) begin
                    if (t.b[i][j] != expect_b) return 0;
                end else if (t.b[i][j] != 0) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_alternating_sign(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (t.a[i][j] != (((i + j) % 2 == 0) ? 7 : -7)) return 0;
                if (t.b[i][j] != (((i + j) % 2 == 0) ? -3 : 3)) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_single_impulse(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (i == N/2 && j == N/3) begin
                    if (t.a[i][j] != 9) return 0;
                end else if (t.a[i][j] != 0) return 0;

                if (i == N/3 && j == N/2) begin
                    if (t.b[i][j] != -4) return 0;
                end else if (t.b[i][j] != 0) return 0;
            end
        end
        return 1;
    endfunction
    function bit is_full_int8_boundary(input item_t t);
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (t.a[i][j] != boundary_value(i + j)) return 0;
                if (t.b[i][j] != ((i == j) ? boundary_value(i + 2*j) : 0)) return 0;
            end
        end
        return 1;
    endfunction
    function bit has_zero_a_row(input item_t t);
        bit found_zero_row;
        bit found_nonzero_a;

        found_zero_row = 0;
        found_nonzero_a = 0;
        for (int i = 0; i < N; i++) begin
            bit row_zero;
            row_zero = 1;
            for (int j = 0; j < N; j++) begin
                if (t.a[i][j] != 0) begin
                    row_zero = 0;
                    found_nonzero_a = 1;
                end
            end
            if (row_zero) found_zero_row = 1;
        end
        return found_zero_row && found_nonzero_a;
    endfunction
    function bit has_zero_b_col(input item_t t);
        bit found_zero_col;
        bit found_nonzero_b;

        found_zero_col = 0;
        found_nonzero_b = 0;
        for (int j = 0; j < N; j++) begin
            bit col_zero;
            col_zero = 1;
            for (int i = 0; i < N; i++) begin
                if (t.b[i][j] != 0) begin
                    col_zero = 0;
                    found_nonzero_b = 1;
                end
            end
            if (col_zero) found_zero_col = 1;
        end
        return found_zero_col && found_nonzero_b;
    endfunction
    virtual function void write(item_t t);
        if(is_zero_matrix(t)) sample_matrix_type = MATRIX_ZERO;
        else if(is_identity_matrix(t)) sample_matrix_type = MATRIX_IDENTITY;
        else if(is_all_positive(t)) sample_matrix_type = ALL_POSITIVE;
        else if(is_all_negative(t)) sample_matrix_type = ALL_NEGATIVE;
        else if(is_sparse(t)) sample_matrix_type = SPARSE;
        else if(is_min_max(t)) sample_matrix_type = MATRIX_MIN_MAX;
        else if(is_alternating_sign(t)) sample_matrix_type = ALTERNATING_SIGN;
        else if(is_single_impulse(t)) sample_matrix_type = SINGLE_IMPULSE;
        else if(is_full_int8_boundary(t)) sample_matrix_type = FULL_INT8_BOUNDARY;
        else if(is_non_diagonal_sparse(t)) sample_matrix_type = NON_DIAGONAL_SPARSE;
        else if(has_zero_a_row(t)) sample_matrix_type = ROW_ZERO;
        else if(has_zero_b_col(t)) sample_matrix_type = COL_ZERO;
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
    function void sample_scenario_cov(item_t::scenario_e scenario);
        // Test-intent scenario coverage. This is sampled by npu_test before
        // sequence start, not by protocol observation in the monitor.
        sample_scenario = scenario;
        cg_scenario.sample();
    endfunction
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV",
            $sformatf("in data cov = %.2f%%, mat pattern cov = %.2f%%, scenario cov = %.2f%%",
                    cg_input_data.get_coverage(),
                    cg_matrix_pattern.get_coverage(),
                    cg_scenario.get_coverage()),
            UVM_LOW)
    endfunction
endclass
class npu_output_coverage #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_subscriber #(npu_sequence_item #(N, width));

    `uvm_component_param_utils(npu_output_coverage #(N, width))

    typedef npu_sequence_item #(N, width) item_t;

    localparam int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1);
    localparam int ACC_MAX   = (1 << (ACC_WIDTH-1)) - 1;
    localparam int ACC_MIN   = -(1 << (ACC_WIDTH-1));
    localparam int SIGNED_MIN = -(1 << (width-1));
    localparam int BOUNDARY_PRODUCT = SIGNED_MIN * SIGNED_MIN;

    int signed sample_c;

    covergroup cg_output_data;
        option.per_instance = 1;

        cp_c_value: coverpoint sample_c {
            bins acc_min_or_below_large = {[ACC_MIN:-BOUNDARY_PRODUCT]};
            bins large_negative         = {[-BOUNDARY_PRODUCT + 1:-101]};
            bins small_negative         = {[-100:-2]};
            bins minus_one              = {-1};
            bins zero                   = {0};
            bins plus_one               = {1};
            bins small_positive         = {[2:100]};
            bins large_positive         = {[101:BOUNDARY_PRODUCT - 1]};
            bins boundary_or_above_pos  = {[BOUNDARY_PRODUCT:ACC_MAX]};
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
