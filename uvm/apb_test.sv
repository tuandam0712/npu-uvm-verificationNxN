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

        phase.raise_objection(this);

        seq = apb_reg_access_sequence::type_id::create("seq");
        seq.start(env.agent.sqr);

        phase.drop_objection(this);
    endtask

endclass