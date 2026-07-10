class npu_sequencer #(
    parameter N = 8,
    parameter width = 8
) extends uvm_sequencer #(npu_sequence_item #(N, width));
    `uvm_component_param_utils(npu_sequencer #(N, width))
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction 
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask
endclass 