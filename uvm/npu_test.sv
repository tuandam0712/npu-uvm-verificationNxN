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
    int num_back_to_back_tests = 20;
    int expected_tests;
    typedef npu_sequence_item #(N, width) item_t;
    typedef item_t::scenario_e scenario_e;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = npu_env #(N, width)::type_id::create("env", this);

        void'(uvm_config_db #(int)::get(this, "", "num_random_tests", num_random_tests));
        void'(uvm_config_db #(int)::get(this, "", "num_back_to_back_tests", num_back_to_back_tests));

        expected_tests = num_directed_tests + num_back_to_back_tests + num_random_tests;
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
        seq.start(env.agent.sqr);

        fork
            begin
                @(posedge env.agent.out_mon.vif.clk iff env.agent.out_mon.vif.done === 1'b1);
            end
            begin
                repeat (5000) @(posedge env.agent.out_mon.vif.clk);
                `uvm_fatal("TEST_TIMEOUT", $sformatf("timeout waiting for done: %s", seq_name))
            end
        join_any
        disable fork;

        repeat (gap_cycles) @(posedge env.agent.out_mon.vif.clk);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        `uvm_info("TEST",
            $sformatf("start NPU test: N=%0d width=%0d directed=%0d btb=%0d random=%0d expected=%0d",
                      N, width, num_directed_tests, num_back_to_back_tests, num_random_tests, expected_tests),
            UVM_LOW)

        // Directed tests
        run_one_sequence(seq_t::ZERO_TEST,         "zero_seq");
        run_one_sequence(seq_t::IDENTITY_TEST,     "identity_seq");
        run_one_sequence(seq_t::MIN_MAX_TEST,      "min_max_seq");
        run_one_sequence(seq_t::ALL_POSITIVE_TEST, "all_positive_seq");
        run_one_sequence(seq_t::ALL_NEGATIVE_TEST, "all_negative_seq");
        run_one_sequence(seq_t::SPARSE_TEST,       "sparse_seq");

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

        server = uvm_report_server::get_server();
        error_count = server.get_severity_count(UVM_ERROR);
        fatal_count = server.get_severity_count(UVM_FATAL);

        expected_tests = num_directed_tests + num_back_to_back_tests + num_random_tests;

        if (error_count > 0 || fatal_count > 0) begin
            `uvm_error("test result",
                $sformatf("failed: tests=%0d directed=%0d btb=%0d random=%0d errors=%0d fatals=%0d",
                          expected_tests, num_directed_tests, num_back_to_back_tests,
                          num_random_tests, error_count, fatal_count))
        end
        else begin
            `uvm_info("test result",
                $sformatf("passed: tests=%0d directed=%0d btb=%0d random=%0d",
                          expected_tests, num_directed_tests,
                          num_back_to_back_tests, num_random_tests),
                UVM_LOW)
        end
    endfunction

endclass