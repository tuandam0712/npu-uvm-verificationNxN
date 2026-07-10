class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    apb_sequencer sqr;
    apb_driver drv;
    apb_monitor mon;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = apb_sequencer::type_id::create("sqr", this);
        drv = apb_driver::type_id::create("drv", this);
        mon = apb_monitor::type_id::create("mon", this);
    endfunction 
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass