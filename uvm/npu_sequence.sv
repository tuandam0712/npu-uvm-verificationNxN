class npu_sequence #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_sequence #(npu_sequence_item #(N, width));
    `uvm_object_param_utils(npu_sequence #(N, width))

    typedef enum {
        IDENTITY_TEST,
        ZERO_TEST,
        RANDOM_TEST,
        MIN_MAX_TEST,
        ALL_POSITIVE_TEST,
        ALL_NEGATIVE_TEST,
        SPARSE_TEST,
        FULL_INT8_RANDOM_TEST,
        BOUNDARY_RANDOM_TEST,
        ROW_ZERO_TEST,
        COL_ZERO_TEST,
        ALTERNATING_SIGN_TEST,
        SINGLE_IMPULSE_TEST,
        FULL_INT8_BOUNDARY_TEST,
        NON_DIAGONAL_SPARSE_TEST
    } test_mode_e;
    typedef npu_sequence_item #(N, width) item_t;
    typedef item_t::scenario_e scenario_e;
    localparam int SIGNED_MIN = -(1 << (width-1));
    localparam int SIGNED_MAX =  (1 << (width-1)) - 1;

    scenario_e scenario = item_t::SCENARIO_NORMAL;
    test_mode_e mode = RANDOM_TEST;

    function new(string name = "npu_sequence");
        super.new(name);
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

    task body();
        npu_sequence_item #(N, width) req;

        req = npu_sequence_item #(N, width)::type_id::create("req");
        req.scenario = scenario;
        start_item(req);

        case (mode)
            // Targets clear/reset leak and zero propagation through every PE.
            ZERO_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = '0;
                    req.b[i][j] = '0;
                end
            end

            // Targets row/column mapping with a simple diagonal reference pattern.
            IDENTITY_TEST: begin
                for (int i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        req.a[i][j] = (i == j) ? 1 : 0;
                        req.b[i][j] = (i == j) ? 1 : 0;
                    end
                end
            end

            // Safe constrained random for routine regression debug around [-64:63].
            RANDOM_TEST: begin
                assert(req.randomize())
                else `uvm_fatal("SEQ", "randomize failed")
            end

            // Full signed-range random targets signedness and accumulator width.
            FULL_INT8_RANDOM_TEST: begin
                req.reasonable.constraint_mode(0);
                assert(req.randomize() with {
                    foreach (a[i,j]) a[i][j] inside {[local::SIGNED_MIN:local::SIGNED_MAX]};
                    foreach (b[i,j]) b[i][j] inside {[local::SIGNED_MIN:local::SIGNED_MAX]};
                })
                else `uvm_fatal("SEQ", "full int8 randomize failed")
            end

            // Boundary-biased random targets signedness and boundary overflow risk.
            BOUNDARY_RANDOM_TEST: begin
                req.reasonable.constraint_mode(0);
                assert(req.randomize() with {
                    foreach (a[i,j]) a[i][j] inside {
                        local::SIGNED_MIN, local::SIGNED_MIN + 1, -1, 0, 1,
                        local::SIGNED_MAX - 1, local::SIGNED_MAX
                    };
                    foreach (b[i,j]) b[i][j] inside {
                        local::SIGNED_MIN, local::SIGNED_MIN + 1, -1, 0, 1,
                        local::SIGNED_MAX - 1, local::SIGNED_MAX
                    };
                })
                else `uvm_fatal("SEQ", "boundary randomize failed")
            end

            // Targets signedness and accumulator width near current safe limits.
            MIN_MAX_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = (i < N/2) ? -64 : 63;
                    req.b[i][j] = (j == 0) ? 0 : ((j < N/2) ? -64 : 63);
                end
            end

            // Targets accumulator growth with all positive products.
            ALL_POSITIVE_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = 63;
                    req.b[i][j] = 63;
                end
            end

            // Targets signed multiply behavior with negative operands.
            ALL_NEGATIVE_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = -64;
                    req.b[i][j] = -64;
                end
            end

            // Targets zero propagation and diagonal-only skew/valid timing.
            SPARSE_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = (i == j) ? 5 : 0;
                    req.b[i][j] = (i == j) ? -2 : 0;
                end
            end

            // Targets zero propagation and A row-to-C row mapping.
            ROW_ZERO_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = ((i == 0) || (i == N-1)) ? 0 : ((i + j) % 5) - 2;
                    req.b[i][j] = ((i * 3 + j) % 7) - 3;
                end
            end

            // Targets zero propagation and B column-to-C column mapping.
            COL_ZERO_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = ((i * 2 + j) % 7) - 3;
                    req.b[i][j] = ((j == 0) || (j == N-1)) ? 0 : ((i + j * 3) % 5) - 2;
                end
            end

            // Targets signedness, skew/valid timing, and alternating product signs.
            ALTERNATING_SIGN_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = ((i + j) % 2 == 0) ? 7 : -7;
                    req.b[i][j] = ((i + j) % 2 == 0) ? -3 : 3;
                end
            end

            // Targets row/column mapping with one expected nonzero contribution.
            SINGLE_IMPULSE_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = '0;
                    req.b[i][j] = '0;
                end
                req.a[N/2][N/3] = 9;
                req.b[N/3][N/2] = -4;
            end

            // Targets signed INT8 boundaries without intentionally overflowing ACC_WIDTH.
            FULL_INT8_BOUNDARY_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = boundary_value(i + j);
                    req.b[i][j] = (i == j) ? boundary_value(i + 2*j) : 0;
                end
            end

            // Targets sparse non-diagonal row/column mapping and skew/valid timing.
            NON_DIAGONAL_SPARSE_TEST: begin
                int col_one;
                int col_prev;
                int mid_next;

                col_one  = (N > 1) ? 1 : 0;
                col_prev = (N > 1) ? N-2 : 0;
                mid_next = (N/2 + 1) % N;

                foreach (req.a[i,j]) begin
                    req.a[i][j] = '0;
                    req.b[i][j] = '0;
                end
                req.a[0][N-1] = 6;
                req.b[N-1][col_one] = -5;
                req.a[N-1][0] = -3;
                req.b[0][col_prev] = 4;
                req.a[N/2][mid_next] = 2;
                req.b[mid_next][N/2] = 7;
            end

            default: begin
                assert(req.randomize())
                else `uvm_fatal("SEQ", "randomize failed")
            end
        endcase

        finish_item(req);
    endtask
endclass
