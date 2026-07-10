class npu_monitor #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_monitor;
    `uvm_component_param_utils(npu_monitor #(N, width))

    typedef npu_sequence_item #(N, width) item_t;

    virtual npu_if #(N, width) vif;
    uvm_analysis_port #(item_t) analysis_port;

    bit is_input_monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        is_input_monitor = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual npu_if #(N, width))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface not found")
        end
        analysis_port = new("analysis_port", this);
    endfunction

    task run_phase(uvm_phase phase);
        if (is_input_monitor) collect_input();
        else                  collect_output();
    endtask

    task collect_input();
        item_t item;
        logic start_d;

        start_d = 1'b0;
        wait(vif.rst_n === 1'b1);
        @(posedge vif.clk);

        forever begin
            @(posedge vif.clk);

            if (vif.start === 1'b1 && start_d === 1'b0) begin
                item = item_t::type_id::create("input_item");

                for (int col = 0; col < N; col++) begin
                    @(posedge vif.clk iff vif.valid_in === 1'b1);
                    for (int i = 0; i < N; i++) begin
                        item.a[i][col] = vif.mon_cb.a[i];
                        item.b[col][i] = vif.mon_cb.b[i];
                    end
                end

                analysis_port.write(item);
                wait(vif.done === 1'b1);
                @(posedge vif.clk);
            end

            start_d = vif.start;
        end
    endtask

    task collect_output();
        item_t item;

        wait(vif.rst_n === 1'b1);

        forever begin
            wait(vif.done === 1'b1);
            @(posedge vif.clk);

            item = item_t::type_id::create("output_item");
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    item.act[i][j] = vif.c[i][j];
                end
            end

            analysis_port.write(item);
            wait(vif.done === 1'b0);
        end
    endtask
endclass
