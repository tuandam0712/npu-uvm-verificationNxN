class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    virtual apb_if vif;
    uvm_analysis_port #(apb_sequence_item) analysis_port;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found")
        end
        analysis_port = new("analysis_port", this);
    endfunction
    task run_phase(uvm_phase phase);
        apb_sequence_item item;
        forever begin
            @(posedge vif.pclk);
            if (vif.presetn != 1'b1) begin
                continue;
            end
            if (vif.psel == 1'b1 && vif.penable == 1'b1 && vif.pready == 1'b1) begin
                item = apb_sequence_item::type_id::create("item");
                item.write = vif.pwrite;
                item.addr = vif.paddr;
                item.wdata = vif.pwdata;
                item.rdata = vif.prdata;
                item.slverr = vif.pslverr;
                analysis_port.write(item);
                `uvm_info("APB_MON",
                    $sformatf("APB %s addr=0x%08h wdata=0x%08h rdata=0x%08h slverr=%0b",
                            item.write ? "WRITE" : "READ",
                            item.addr,
                            item.wdata,
                            item.rdata,
                            item.slverr),
                    UVM_LOW)
            end
        end
    endtask
endclass