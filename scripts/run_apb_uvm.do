transcript file reports/apb_regression.log

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

vlog -sv +incdir+rtl rtl/pe.sv
vlog -sv +incdir+rtl rtl/systolic_arr_NxN.sv
vlog -sv +incdir+rtl rtl/sa_controller_NxN.sv
vlog -sv +incdir+rtl rtl/npu_top_NXN.sv
vlog -sv +incdir+rtl rtl/apb_npu_wrapper.sv

vlog -sv +incdir+uvm uvm/apb_if.sv
vlog -sv +incdir+uvm uvm/apb_pkg.sv

vlog -sv +incdir+uvm uvm/apb_protocol_sva.sv

vlog -sv +incdir+uvm +incdir+rtl tb/tb_apb_npu_wrapper.sv

vsim -voptargs="+acc" work.tb_apb_npu_wrapper

run -all

quit -f
