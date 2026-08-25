class apb_base_sequence extends uvm_sequence #(apb_sequence_item);

    `uvm_object_utils(apb_base_sequence)

    function new(string name = "apb_base_sequence");
        super.new(name);
    endfunction

    task apb_write(
        input bit [31:0] addr,
        input bit [31:0] data,
        input bit        exp_slverr = 1'b0
    );
        apb_sequence_item item;

        item = apb_sequence_item::type_id::create("item");

        start_item(item);
        item.write = 1'b1;
        item.addr  = addr;
        item.wdata = data;
        finish_item(item);

        if(item.slverr !== exp_slverr) begin
            `uvm_error("APB_SEQ", $sformatf("WRITE SLVERR mismatch addr=0x%08h expected=%0b actual=%0b", addr, exp_slverr, item.slverr))
        end
    endtask

    task apb_read(
        input bit [31:0] addr,
        input bit        exp_slverr = 1'b0
    );
        apb_sequence_item item;

        item = apb_sequence_item::type_id::create("item");

        start_item(item);
        item.write = 1'b0;
        item.addr  = addr;
        item.wdata = 32'h0;
        finish_item(item);

        if(item.slverr !== exp_slverr) begin
            `uvm_error("APB_SEQ", $sformatf("READ SLVERR mismatch addr=0x%08h expected=%0b actual=%0b", addr, exp_slverr, item.slverr))
        end
    endtask

    task apb_read_data(
        input  bit [31:0] addr,
        output bit [31:0] data,
        input  bit        exp_slverr = 1'b0
    );
        apb_sequence_item item;

        item = apb_sequence_item::type_id::create("item");

        start_item(item);
        item.write = 1'b0;
        item.addr  = addr;
        item.wdata = 32'h0;
        finish_item(item);

        data = item.rdata;

        if(item.slverr !== exp_slverr) begin
            `uvm_error("APB_SEQ", $sformatf("READ_DATA SLVERR mismatch addr=0x%08h expected=%0b actual=%0b", addr, exp_slverr, item.slverr))
        end
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
        apb_write(APB_CONTROL_ADDR, 32'h0000_0000);
        apb_read (APB_CONTROL_ADDR, 1'b1);

        // STATUS register
        apb_read (APB_STATUS_ADDR);

        // A matrix region
        apb_write(APB_A_BASE, 32'h0000_0001);
        apb_read (APB_A_BASE, 1'b1);

        // B matrix region
        apb_write(APB_B_BASE, 32'h0000_0002);
        apb_read (APB_B_BASE, 1'b1);

        // C matrix region
        // apb_read (APB_C_BASE);

        // Unsp wr dir
        apb_write(APB_STATUS_ADDR, 32'h0000_0001, 1'b1);
        apb_write(APB_C_BASE, 32'h0000_0001, 1'b1);

        // Invalid addr
        apb_read(32'h0000_0008, 1'b1);

        // Misaligned A addr
        apb_write(
            APB_A_BASE + 32'h1, 32'h0000_0055, 1'b1
        );

        `uvm_info("APB_SEQ", "Finished APB register access sequence", UVM_LOW)
    endtask

endclass
class apb_matrix_compute_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_matrix_compute_sequence)

    function new(string name = "apb_matrix_compute_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;
        int val;

        `uvm_info("APB_SEQ", "Starting APB matrix compute sequence", UVM_LOW)

        // 1. Write A = identity matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                if (i == j)
                    apb_write(apb_a_addr(i, j), 32'h0000_0001);
                else
                    apb_write(apb_a_addr(i, j), 32'h0000_0000);
            end
        end

        // 2. Write B = simple positive pattern
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                val = (i * APB_N + j + 1) & 8'h7F;
                apb_write(apb_b_addr(i, j), val);
            end
        end

        // 3. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        // 4. Poll done bit
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("NPU done observed after %0d polls, status=0x%08h",
                      poll_count, status),
            UVM_LOW)

        // 5. Read C matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB matrix compute sequence", UVM_LOW)
    endtask

endclass
class apb_zero_matrix_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_zero_matrix_sequence)

    function new(string name = "apb_zero_matrix_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;
        int val;

        `uvm_info("APB_SEQ", "Starting APB zero matrix sequence", UVM_LOW)

        // 1. Write A = zero matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_write(apb_a_addr(i, j), 32'h0000_0000);
            end
        end

        // 2. Write B = simple positive pattern
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                val = (i * APB_N + j + 1) & 8'h7F;
                apb_write(apb_b_addr(i, j), val);
            end
        end

        // 3. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        // 4. Poll done bit
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done in zero matrix sequence")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("Zero matrix done observed after %0d polls, status=0x%08h",
                      poll_count, status),
            UVM_LOW)

        // 5. Read C matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB zero matrix sequence", UVM_LOW)
    endtask

endclass
class apb_sparse_matrix_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_sparse_matrix_sequence)

    function new(string name = "apb_sparse_matrix_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;
        int val;

        `uvm_info("APB_SEQ", "Starting APB sparse matrix sequence", UVM_LOW)

        // 1. Write A = sparse diagonal matrix, diagonal = 2
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                if (i == j)
                    apb_write(apb_a_addr(i, j), 32'h0000_0002);
                else
                    apb_write(apb_a_addr(i, j), 32'h0000_0000);
            end
        end

        // 2. Write B = simple positive pattern
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                val = (i * APB_N + j + 1) & 8'h7F;
                apb_write(apb_b_addr(i, j), val);
            end
        end

        // 3. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        // 4. Poll done bit
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done in sparse matrix sequence")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("Sparse matrix done observed after %0d polls, status=0x%08h",
                      poll_count, status),
            UVM_LOW)

        // 5. Read C matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB sparse matrix sequence", UVM_LOW)
    endtask

endclass
class apb_random_matrix_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_random_matrix_sequence)

    function new(string name = "apb_random_matrix_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;
        int a_val;
        int b_val;

        `uvm_info("APB_SEQ", "Starting APB random matrix sequence", UVM_LOW)

        // 1. Write A = bounded deterministic random-like pattern
        // Values are small to avoid overflow and make debug easier.
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                a_val = ((i * 3 + j * 5 + 1) % 4); // 0..3
                apb_write(apb_a_addr(i, j), a_val);
            end
        end

        // 2. Write B = bounded deterministic random-like pattern
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                b_val = ((i * 7 + j * 2 + 3) % 4); // 0..3
                apb_write(apb_b_addr(i, j), b_val);
            end
        end

        // 3. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        // 4. Poll done bit
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done in random matrix sequence")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("Random matrix done observed after %0d polls, status=0x%08h",
                      poll_count, status),
            UVM_LOW)

        // 5. Read C matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB random matrix sequence", UVM_LOW)
    endtask

endclass
class apb_signed_matrix_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_signed_matrix_sequence)

    function new(string name = "apb_signed_matrix_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;
        int val;

        `uvm_info("APB_SEQ", "Starting APB signed matrix sequence", UVM_LOW)

        // 1. Write A = diagonal matrix, diagonal = -1
        // For 8-bit signed, -1 = 8'hFF.
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                if (i == j)
                    apb_write(apb_a_addr(i, j), 32'h0000_00FF);
                else
                    apb_write(apb_a_addr(i, j), 32'h0000_0000);
            end
        end

        // 2. Write B = positive pattern 1..64
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                val = i * APB_N + j + 1;
                apb_write(apb_b_addr(i, j), val);
            end
        end

        // 3. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        // 4. Poll done bit
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done in signed matrix sequence")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("Signed matrix done observed after %0d polls, status=0x%08h",
                      poll_count, status),
            UVM_LOW)

        // 5. Read C matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB signed matrix sequence", UVM_LOW)
    endtask

endclass
class apb_status_behavior_sequence extends apb_base_sequence;

    `uvm_object_utils(apb_status_behavior_sequence)

    function new(string name = "apb_status_behavior_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] status;
        int poll_count;

        `uvm_info("APB_SEQ", "Starting APB status behavior sequence", UVM_LOW)

        // 1. Read STATUS before start
        apb_read_data(APB_STATUS_ADDR, status);

        `uvm_info("APB_SEQ",
            $sformatf("STATUS before new start = 0x%08h done=%0b busy=%0b",
                      status, status[0], status[1]),
            UVM_LOW)

        // 2. Write A = identity matrix
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                if (i == j)
                    apb_write(apb_a_addr(i, j), 32'h0000_0001);
                else
                    apb_write(apb_a_addr(i, j), 32'h0000_0000);
            end
        end

        // 3. Write B = simple pattern
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_write(apb_b_addr(i, j), i * APB_N + j + 1);
            end
        end

        // 4. Start NPU
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001);

        apb_write(APB_A_BASE, 32'h0000_0007, 1'b1);
        apb_write(APB_CONTROL_ADDR, 32'h0000_0001, 1'b1);

        // 5. Read STATUS immediately after start a few times
        for (int k = 0; k < 3; k++) begin
            apb_read_data(APB_STATUS_ADDR, status);

            `uvm_info("APB_SEQ",
                $sformatf("STATUS during compute sample %0d = 0x%08h done=%0b busy=%0b",
                          k, status, status[0], status[1]),
                UVM_LOW)
        end

        // 6. Poll until done
        poll_count = 0;
        do begin
            apb_read_data(APB_STATUS_ADDR, status);
            poll_count++;

            if (poll_count > 200) begin
                `uvm_error("APB_SEQ", "Timeout waiting for NPU done in status behavior sequence")
                break;
            end
        end while (status[0] !== 1'b1);

        `uvm_info("APB_SEQ",
            $sformatf("STATUS done observed after %0d polls, status=0x%08h done=%0b busy=%0b",
                      poll_count, status, status[0], status[1]),
            UVM_LOW)

        // 7. Read STATUS after done
        apb_read_data(APB_STATUS_ADDR, status);

        `uvm_info("APB_SEQ",
            $sformatf("STATUS after done = 0x%08h done=%0b busy=%0b",
                      status, status[0], status[1]),
            UVM_LOW)

        // 8. Read C matrix to let scoreboard check this compute too
        for (int i = 0; i < APB_N; i++) begin
            for (int j = 0; j < APB_N; j++) begin
                apb_read(apb_c_addr(i, j));
            end
        end

        `uvm_info("APB_SEQ", "Finished APB status behavior sequence", UVM_LOW)
    endtask

endclass