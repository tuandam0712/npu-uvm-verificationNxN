class npu_driver #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_driver #(npu_sequence_item #(N, width));
    `uvm_component_param_utils(npu_driver #(N, width))

    typedef npu_sequence_item #(N, width) item_t;

    virtual npu_if #(N, width) vif;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual npu_if #(N, width))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface not found")
        end
    endfunction

    task run_phase(uvm_phase phase);
        item_t req;

        wait(vif.rst_n === 1'b1);
        @(posedge vif.clk);

        forever begin
            seq_item_port.get_next_item(req);
            wait(vif.done === 1'b0);
            @(posedge vif.clk);
            drive_transaction(req);
            seq_item_port.item_done();
            wait(vif.done === 1'b1);
            @(posedge vif.clk);
        end
    endtask

    task drive_transaction(item_t item);
        vif.start <= 1'b1;
        @(posedge vif.clk);
        vif.start <= 1'b0;

        wait(vif.valid_in === 1'b1);

        for (int col = 0; col < N; col++) begin
            for (int i = 0; i < N; i++) begin
                vif.a[i] <= item.a[i][col];
                vif.b[i] <= item.b[col][i];
            end
            @(posedge vif.clk);
        end

        for (int i = 0; i < N; i++) begin
            vif.a[i] <= '0;
            vif.b[i] <= '0;
        end
        @(posedge vif.clk);
    endtask
endclass
