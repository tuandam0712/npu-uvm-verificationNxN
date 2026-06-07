class npu_test_N8 extends npu_test #(8,8);
    `uvm_component_utils(npu_test_N8)
    
    function new(string name = "npu_test_N8", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass