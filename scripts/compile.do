file mkdir logs
transcript file logs/compile.log
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work
vlog -sv +cover=sbcfe rtl/pe.sv
vlog -sv +cover=sbcfe rtl/sa_controller_NxN.sv
vlog -sv +cover=sbcfe rtl/systolic_arr_NxN.sv
vlog -sv +cover=sbcfe rtl/npu_top_NxN.sv
vlog -sv +cover=sbcfe rtl/apb_npu_wrapper.sv
vlog -sv uvm/npu_if.sv
vlog -sv +incdir+uvm uvm/npu_pkg.sv
vlog -sv tb/tb_npu_nxn.sv
vlog -sv tb/tb_rtl_random.sv
vlog -sv tb/apb_wrapper_smoke_tb.sv
puts "compile completed."