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
    localparam int SIGNED_MIN = -(1 << (width-1));
    localparam int SIGNED_MAX =  (1 << (width-1)) - 1;
    localparam int SAFE_MIN   = (SIGNED_MIN < -64) ? -64 : SIGNED_MIN;
    localparam int SAFE_MAX   = (SIGNED_MAX >  63) ?  63 : SIGNED_MAX;

    rand bit signed [width-1:0] a [N-1:0][N-1:0];
    rand bit signed [width-1:0] b [N-1:0][N-1:0];

    bit signed [ACC_WIDTH-1:0] exp [N-1:0][N-1:0];
    bit signed [ACC_WIDTH-1:0] act [N-1:0][N-1:0];

    constraint reasonable {
        foreach (a[i,j]) a[i][j] inside {[SAFE_MIN:SAFE_MAX]};
        foreach (b[i,j]) b[i][j] inside {[SAFE_MIN:SAFE_MAX]};
    }

    function new(string name = "npu_sequence_item");
        super.new(name);
    endfunction
endclass
