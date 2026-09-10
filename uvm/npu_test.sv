class npu_test #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_test;

    `uvm_component_param_utils(npu_test #(N, width))

    typedef npu_sequence #(N, width) seq_t;
    typedef seq_t::test_mode_e test_mode_t;

    npu_env #(N, width) env;

    int num_random_tests       = 100;
    int num_directed_tests     = 6;
    int num_extended_directed_tests = 6;
    int num_back_to_back_tests = 20;
    int num_full_int8_random_tests = 5;
    int num_boundary_random_tests = 5;
    int expected_tests;
    typedef npu_sequence_item #(N, width) item_t;
    typedef item_t::scenario_e scenario_e;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function automatic string mode_name(test_mode_t mode);
        case (mode)
            seq_t::IDENTITY_TEST:            mode_name = "IDENTITY_TEST";
            seq_t::ZERO_TEST:                mode_name = "ZERO_TEST";
            seq_t::RANDOM_TEST:              mode_name = "RANDOM_TEST";
            seq_t::MIN_MAX_TEST:             mode_name = "MIN_MAX_TEST";
            seq_t::ALL_POSITIVE_TEST:        mode_name = "ALL_POSITIVE_TEST";
            seq_t::ALL_NEGATIVE_TEST:        mode_name = "ALL_NEGATIVE_TEST";
            seq_t::SPARSE_TEST:              mode_name = "SPARSE_TEST";
            seq_t::FULL_INT8_RANDOM_TEST:    mode_name = "FULL_INT8_RANDOM_TEST";
            seq_t::BOUNDARY_RANDOM_TEST:     mode_name = "BOUNDARY_RANDOM_TEST";
            seq_t::ROW_ZERO_TEST:            mode_name = "ROW_ZERO_TEST";
            seq_t::COL_ZERO_TEST:            mode_name = "COL_ZERO_TEST";
            seq_t::ALTERNATING_SIGN_TEST:    mode_name = "ALTERNATING_SIGN_TEST";
            seq_t::SINGLE_IMPULSE_TEST:      mode_name = "SINGLE_IMPULSE_TEST";
            seq_t::FULL_INT8_BOUNDARY_TEST:  mode_name = "FULL_INT8_BOUNDARY_TEST";
            seq_t::NON_DIAGONAL_SPARSE_TEST: mode_name = "NON_DIAGONAL_SPARSE_TEST";
            default:                         mode_name = "UNKNOWN_TEST";
        endcase
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = npu_env #(N, width)::type_id::create("env", this);

        void'(uvm_config_db #(int)::get(this, "", "num_random_tests", num_random_tests));
        void'(uvm_config_db #(int)::get(this, "", "num_back_to_back_tests", num_back_to_back_tests));
        void'(uvm_config_db #(int)::get(this, "", "num_full_int8_random_tests", num_full_int8_random_tests));
        void'(uvm_config_db #(int)::get(this, "", "num_boundary_random_tests", num_boundary_random_tests));

        expected_tests = num_directed_tests + num_extended_directed_tests +
                         num_full_int8_random_tests + num_boundary_random_tests +
                         num_back_to_back_tests + num_random_tests;
    endfunction

    task run_one_sequence(
        test_mode_t mode,
        string seq_name,
        int gap_cycles = 5,
        scenario_e scenario = item_t::SCENARIO_NORMAL
    );
        seq_t seq;

        seq = seq_t::type_id::create(seq_name);
        seq.mode = mode;
        seq.scenario = scenario;
        env.cov.sample_scenario_cov(scenario);
        `uvm_info("TEST",
            $sformatf("running seq=%s mode=%s scenario=%0d gap_cycles=%0d",
                      seq_name, mode_name(mode), scenario, gap_cycles),
            UVM_LOW)
        fork
            begin
                fork
                    begin
                        seq.start(env.agent.sqr);
                    end
                    begin
                        repeat (5000) @(posedge env.agent.out_mon.vif.clk);
                        `uvm_fatal("TEST_TIMEOUT", $sformatf("timeout waiting for sequence completion: %s", seq_name))
                    end
                join_any
                disable fork;
            end
        join

        repeat (gap_cycles) @(posedge env.agent.out_mon.vif.clk);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        `uvm_info("TEST",
            $sformatf("start NPU test: N=%0d width=%0d directed=%0d extended_directed=%0d full_int8_random=%0d boundary_random=%0d btb=%0d random=%0d expected=%0d",
                      N, width, num_directed_tests, num_extended_directed_tests,
                      num_full_int8_random_tests, num_boundary_random_tests,
                      num_back_to_back_tests, num_random_tests, expected_tests),
            UVM_LOW)

        // Original directed tests
        `uvm_info("TEST", "running original directed tests", UVM_LOW)
        if ($test$plusargs("RESET_DURING_DRAIN") ||
            $test$plusargs("RESET_DURING_COMPUTE")) begin
            // Nonzero victim exposes stale accumulator/input state after reset.
            run_one_sequence(seq_t::ALL_POSITIVE_TEST, "reset_victim_seq");
        end else begin
            run_one_sequence(seq_t::ZERO_TEST, "zero_seq");
        end
        run_one_sequence(seq_t::IDENTITY_TEST,     "identity_seq");
        run_one_sequence(seq_t::MIN_MAX_TEST,      "min_max_seq");
        run_one_sequence(seq_t::ALL_POSITIVE_TEST, "all_positive_seq");
        run_one_sequence(seq_t::ALL_NEGATIVE_TEST, "all_negative_seq");
        run_one_sequence(seq_t::SPARSE_TEST,       "sparse_seq");

        // Extended directed tests
        `uvm_info("TEST", "running extended directed tests", UVM_LOW)
        run_one_sequence(seq_t::ROW_ZERO_TEST,              "row_zero_seq");
        run_one_sequence(seq_t::COL_ZERO_TEST,              "col_zero_seq");
        run_one_sequence(seq_t::ALTERNATING_SIGN_TEST,      "alternating_sign_seq");
        run_one_sequence(seq_t::SINGLE_IMPULSE_TEST,        "single_impulse_seq");
        run_one_sequence(seq_t::FULL_INT8_BOUNDARY_TEST,    "full_int8_boundary_seq");
        run_one_sequence(seq_t::NON_DIAGONAL_SPARSE_TEST,   "non_diagonal_sparse_seq");

        // Full-range random tests: small count to keep high-risk coverage affordable.
        `uvm_info("TEST", "running full signed INT8 random tests", UVM_LOW)
        for (int i = 0; i < num_full_int8_random_tests; i++) begin
            run_one_sequence(seq_t::FULL_INT8_RANDOM_TEST,
                             $sformatf("full_int8_rand_seq_%0d", i));
        end

        // Boundary-biased random tests
        `uvm_info("TEST", "running boundary-biased random tests", UVM_LOW)
        for (int i = 0; i < num_boundary_random_tests; i++) begin
            run_one_sequence(seq_t::BOUNDARY_RANDOM_TEST,
                             $sformatf("boundary_rand_seq_%0d", i));
        end

        // Back-to-back random tests: gap_cycles = 0
        `uvm_info("TEST", "running back-to-back random tests", UVM_LOW)

        for (int i = 0; i < num_back_to_back_tests; i++) begin
            run_one_sequence(seq_t::RANDOM_TEST,
                            $sformatf("back_to_back_rand_seq_%0d", i),
                            0,
                            item_t::SCENARIO_BACK_TO_BACK);
        end

        // Normal random tests
        for (int iter = 0; iter < num_random_tests; iter++) begin
            run_one_sequence(seq_t::RANDOM_TEST,
                             $sformatf("rand_seq_%0d", iter));
        end

        repeat (10) @(posedge env.agent.out_mon.vif.clk);

        phase.drop_objection(this);
    endtask

    function void check_phase(uvm_phase phase);
        uvm_report_server server;
        int error_count;
        int fatal_count;
        int expected_aborted;
        int expected_completed;
        bit counts_ok;

        server = uvm_report_server::get_server();
        error_count = server.get_severity_count(UVM_ERROR);
        fatal_count = server.get_severity_count(UVM_FATAL);

        expected_tests = num_directed_tests + num_extended_directed_tests +
                         num_full_int8_random_tests + num_boundary_random_tests +
                         num_back_to_back_tests + num_random_tests;

        // Expectations come from the selected scenario, not observed aborts.
        expected_aborted = ($test$plusargs("RESET_DURING_DRAIN") ||
                            $test$plusargs("RESET_DURING_COMPUTE")) ? 1 : 0;
        expected_completed = expected_tests - expected_aborted;
        counts_ok = (env.agent.drv.aborted_cnt == expected_aborted &&
                     env.scb.pass_count == expected_completed &&
                     env.scb.fail_count == 0 &&
                     env.scb.in_fifo.used() == 0 && env.scb.out_fifo.used() == 0);

        `uvm_info("NPU_ACCOUNTING",
            $sformatf("requested=%0d expected_completed=%0d completed=%0d expected_aborted=%0d aborted=%0d mismatches=%0d pending_in=%0d pending_out=%0d",
                      expected_tests, expected_completed, env.scb.pass_count,
                      expected_aborted, env.agent.drv.aborted_cnt, env.scb.fail_count,
                      env.scb.in_fifo.used(), env.scb.out_fifo.used()), UVM_LOW)

        if (!counts_ok) begin
            `uvm_error("test result",
                "Transaction accounting mismatch; see NPU_ACCOUNTING summary")
        end

        if (error_count > 0 || fatal_count > 0 || !counts_ok) begin
            `uvm_error("test result",
                $sformatf("failed: tests=%0d directed=%0d extended_directed=%0d full_int8_random=%0d boundary_random=%0d btb=%0d random=%0d scb_pass=%0d scb_fail=%0d errors=%0d fatals=%0d",
                          expected_tests, num_directed_tests, num_extended_directed_tests,
                          num_full_int8_random_tests, num_boundary_random_tests,
                          num_back_to_back_tests, num_random_tests,
                          env.scb.pass_count, env.scb.fail_count, error_count, fatal_count))
        end
        else begin
            `uvm_info("test result",
                $sformatf("passed: tests=%0d directed=%0d extended_directed=%0d full_int8_random=%0d boundary_random=%0d btb=%0d random=%0d scb_pass=%0d",
                          expected_tests, num_directed_tests, num_extended_directed_tests,
                          num_full_int8_random_tests, num_boundary_random_tests,
                          num_back_to_back_tests, num_random_tests, env.scb.pass_count),
                UVM_LOW)
        end
    endfunction

endclass
