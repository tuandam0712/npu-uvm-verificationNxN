class npu_sequence #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_sequence #(npu_sequence_item #(N, width));
    `uvm_object_param_utils(npu_sequence #(N, width))

    typedef enum {
        IDENTITY_TEST,
        ZERO_TEST,
        RANDOM_TEST
    } test_mode_e;

    test_mode_e mode = RANDOM_TEST;

    function new(string name = "npu_sequence");
        super.new(name);
    endfunction

    task body();
        npu_sequence_item #(N, width) req;

        req = npu_sequence_item #(N, width)::type_id::create("req");
        start_item(req);

        case (mode)
            ZERO_TEST: begin
                foreach (req.a[i,j]) begin
                    req.a[i][j] = '0;
                    req.b[i][j] = '0;
                end
            end

            IDENTITY_TEST: begin
                for (int i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        req.a[i][j] = (i == j) ? 1 : 0;
                        req.b[i][j] = (i == j) ? 1 : 0;
                    end
                end
            end

            RANDOM_TEST: begin
                assert(req.randomize())
                else `uvm_fatal("SEQ", "Randomization failed")
            end
        endcase

        finish_item(req);
    endtask
endclass
