file mkdir logs
transcript file logs/compile.log

if {[file exists work]} {
    vdel -all -lib work
}

vlib work
vmap work work
set ROOT_DIR [pwd]
if {[info exists ::env(UVM_HOME)]} {
    set UVM_SRC "$::env(UVM_HOME)/src"
} else {
    puts "ERROR: UVM_HOME environment variable not found."
    quit -code 1
}

vlog -sv +cover=sbcfe rtl/pe.sv
vlog -sv sva/pe_sva.sv
vlog -sv sva/pe_bind.sv
vlog -sv +cover=sbcfe rtl/sa_controller_NxN.sv
vlog -sv +cover=sbcfe rtl/systolic_arr_NxN.sv
vlog -sv +cover=sbcfe rtl/npu_top_NXN.sv
vlog -sv +cover=sbcfe rtl/apb_npu_wrapper.sv

vlog -sv uvm/npu_if.sv

vlog -sv +incdir+$UVM_SRC $UVM_SRC/uvm_pkg.sv

vlog -sv +incdir+uvm +incdir+$UVM_SRC uvm/npu_pkg.sv


vlog -sv +incdir+$UVM_SRC tb/tb_npu_nxn.sv
vlog -sv tb/tb_rtl_random.sv
vlog -sv tb/apb_wrapper_smoke_tb.sv

puts "Compile completed."
