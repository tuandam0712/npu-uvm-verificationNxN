class apb_driver extends uvm_driver #(apb_sequence_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if vif;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction 
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("APB_DRV", "Virtual interface not found")
        end
    endfunction
    task run_phase(uvm_phase phase);
        apb_sequence_item req;
        reset_bus();
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask
    task reset_bus();
        vif.psel <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite <= 1'b0;
        vif.paddr <= 32'h0;
        vif.pwdata <= 32'h0;
        wait (vif.presetn == 1'b1);
        @(posedge vif.pclk);
    endtask
    task drive_transfer(apb_sequence_item item);

        // IDLE -> SETUP
        @(posedge vif.pclk);
        vif.psel    <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwrite  <= item.write;
        vif.paddr   <= item.addr;
        vif.pwdata  <= item.wdata;

        // SETUP -> ACCESS
        @(posedge vif.pclk);
        vif.penable <= 1'b1;

        // Stay in ACCESS until slave is ready
        do begin
            @(posedge vif.pclk);
        end while (vif.pready !== 1'b1);

        // Sample response at completed ACCESS cycle
        item.rdata  = vif.prdata;
        item.slverr = vif.pslverr;
        if (item.slverr) begin
            `uvm_warning("APB_DRV",
                $sformatf("APB slave error detected addr=0x%08h write=%0b",
                        item.addr, item.write))
        end
        // ACCESS -> IDLE
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= 32'h0;
        vif.pwdata  <= 32'h0;

    endtask
endclass