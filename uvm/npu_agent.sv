class npu_agent #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_agent;
    `uvm_component_param_utils(npu_agent #(N, width))

    npu_sequencer #(N, width) sqr;
    npu_driver    #(N, width) drv;
    npu_monitor   #(N, width) in_mon;
    npu_monitor   #(N, width) out_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        in_mon = npu_monitor #(N, width)::type_id::create("in_mon", this);
        in_mon.is_input_monitor = 1'b1;

        out_mon = npu_monitor #(N, width)::type_id::create("out_mon", this);
        out_mon.is_input_monitor = 1'b0;

        if (get_is_active() == UVM_ACTIVE) begin
            drv = npu_driver #(N, width)::type_id::create("drv", this);
            sqr = npu_sequencer #(N, width)::type_id::create("sqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass
