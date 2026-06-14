class npu_sequence_item #(
    parameter int N = 8,
    parameter int width = 8
) extends uvm_sequence_item;
    `uvm_object_param_utils(npu_sequence_item #(N, width))
    typedef enum int {
        SCENARIO_NORMAL,
        SCENARIO_BACK_TO_BACK
    } scenario_e;
    scenario_e scenario = SCENARIO_NORMAL;
    localparam int ACC_WIDTH = 2*width + ((N > 1) ? $clog2(N) : 1);

    rand bit signed [width-1:0] a [N-1:0][N-1:0];
    rand bit signed [width-1:0] b [N-1:0][N-1:0];

    bit signed [ACC_WIDTH-1:0] exp [N-1:0][N-1:0];
    bit signed [ACC_WIDTH-1:0] act [N-1:0][N-1:0];

    constraint reasonable {
        foreach (a[i,j]) a[i][j] inside {[-64:63]};
        foreach (b[i,j]) b[i][j] inside {[-64:63]};
    }

    function new(string name = "npu_sequence_item");
        super.new(name);
    endfunction
endclass
