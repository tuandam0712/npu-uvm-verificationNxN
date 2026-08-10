class apb_test extends uvm_test;

    `uvm_component_utils(apb_test)

    apb_env env;

    function new(string name = "apb_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = apb_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        apb_reg_access_sequence seq;
        apb_matrix_compute_sequence compute_seq;
        apb_zero_matrix_sequence zero_seq;
        apb_sparse_matrix_sequence sparse_seq;
        apb_random_matrix_sequence random_seq;
        apb_signed_matrix_sequence signed_seq;
        apb_status_behavior_sequence status_seq;
        phase.raise_objection(this);

        seq = apb_reg_access_sequence::type_id::create("seq");
        seq.start(env.agent.sqr);
        compute_seq = apb_matrix_compute_sequence::type_id::create("compute_seq");
        compute_seq.start(env.agent.sqr);
        zero_seq = apb_zero_matrix_sequence::type_id::create("zero_seq");
        zero_seq.start(env.agent.sqr);
        sparse_seq = apb_sparse_matrix_sequence::type_id::create("sparse_seq");
        sparse_seq.start(env.agent.sqr);
        random_seq = apb_random_matrix_sequence::type_id::create("random_seq");
        random_seq.start(env.agent.sqr);
        signed_seq = apb_signed_matrix_sequence::type_id::create("signed_seq");
        signed_seq.start(env.agent.sqr);
        status_seq = apb_status_behavior_sequence::type_id::create("status_seq");   
        status_seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask

endclass