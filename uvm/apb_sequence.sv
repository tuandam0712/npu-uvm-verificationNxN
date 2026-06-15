class apb_base_sequence extends uvm_sequence #(apb_sequence_item);

    `uvm_object_utils(apb_base_sequence)

    function new(string name = "apb_base_sequence");
        super.new(name);
    endfunction

    task apb_write(bit [31:0] addr, bit [31:0] data);
        apb_sequence_item item;

        item = apb_sequence_item::type_id::create("item");

        start_item(item);
        item.write = 1'b1;
        item.addr  = addr;
        item.wdata = data;
        finish_item(item);
    endtask

    task apb_read(bit [31:0] addr);
        apb_sequence_item item;

        item = apb_sequence_item::type_id::create("item");

        start_item(item);
        item.write = 1'b0;
        item.addr  = addr;
        item.wdata = 32'h0;
        finish_item(item);
    endtask

endclass
class apb_smoke_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_smoke_sequence)

    function new(string name = "apb_smoke_sequence");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_SEQ", "Starting APB smoke sequence", UVM_LOW)

        apb_write(32'h0000_0000, 32'h0000_0001);
        apb_read (32'h0000_0004);

        `uvm_info("APB_SEQ", "Finished APB smoke sequence", UVM_LOW)
    endtask

endclass
class apb_reg_access_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_reg_access_sequence)

    function new(string name = "apb_reg_access_sequence");
        super.new(name);
    endfunction

    task body();
        `uvm_info("APB_SEQ", "Starting APB register access sequence", UVM_LOW)

        // CONTROL register
        apb_write(32'h0000_0000, 32'h0000_0000);
        apb_read (32'h0000_0000);

        // STATUS register
        apb_read (32'h0000_0004);

        // A matrix region
        apb_write(32'h0000_0010, 32'h0000_0001);
        apb_read (32'h0000_0010);

        // B matrix region
        apb_write(32'h0000_0040, 32'h0000_0002);
        apb_read (32'h0000_0040);

        // C matrix region
        apb_read (32'h0000_0080);

        `uvm_info("APB_SEQ", "Finished APB register access sequence", UVM_LOW)
    endtask

endclass