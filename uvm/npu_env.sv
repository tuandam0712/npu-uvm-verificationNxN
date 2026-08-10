class npu_env #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_env;
    `uvm_component_param_utils(npu_env #(N, width))
    npu_agent      #(N, width) agent;
    npu_scoreboard #(N, width) scb;
    npu_coverage #(N, width) cov;
    npu_output_coverage #(N, width) out_cov;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = npu_agent      #(N, width)::type_id::create("agent", this);
        scb   = npu_scoreboard #(N, width)::type_id::create("scb", this);
        cov = npu_coverage #(N, width)::type_id::create("cov", this);
        out_cov = npu_output_coverage #(N, width)::type_id::create("out_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.in_mon.analysis_port.connect(scb.in_export);
        agent.out_mon.analysis_port.connect(scb.out_export);
        agent.in_mon.analysis_port.connect(cov.analysis_export);
        agent.out_mon.analysis_port.connect(out_cov.analysis_export);
    endfunction
endclass
