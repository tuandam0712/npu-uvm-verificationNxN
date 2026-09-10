# Run from the repository root: do scripts/run_npu_reset.do [all|baseline|compute|drain]
# Dedicated library avoids deleting APB or other work libraries.
onerror {quit -f -code 1}
set mode all
if {$argc > 0} {set mode $1}
if {$mode ni {all baseline compute drain}} {error "Use all, baseline, compute, or drain"}
set modes [list $mode]
if {$mode eq "all"} {set modes {baseline compute drain}}
file mkdir logs
set lib npu_reset_work
if {![file exists $lib]} {vlib $lib}
vmap $lib $lib

if {[info exists ::env(UVM_HOME)]} {
    set uvm_root $::env(UVM_HOME)
} else {
    set uvm_root [file normalize [file join [file dirname [info nameofexecutable]] .. verilog_src uvm-1.1d]]
}
set uvm_src [file join $uvm_root src]
set dpi [file normalize [file join [file dirname [info nameofexecutable]] .. uvm-1.1d win64 uvm_dpi]]
if {![file exists [file join $uvm_src uvm_pkg.sv]] || ![file exists ${dpi}.dll]} {
    error "Requires Questa Windows UVM 1.1d sources and win64/uvm_dpi.dll; set UVM_HOME if necessary"
}
transcript file logs/npu_reset_compile.log
vlog -work $lib -sv rtl/pe.sv rtl/sa_controller_NxN.sv rtl/systolic_arr_NxN.sv rtl/npu_top_NXN.sv uvm/npu_if.sv
vlog -work $lib -sv +incdir+$uvm_src $uvm_src/uvm_pkg.sv
vlog -work $lib -sv +incdir+uvm +incdir+$uvm_src uvm/npu_pkg.sv
vlog -work $lib -sv +incdir+$uvm_src tb/tb_npu_nxn.sv

foreach scenario $modes {
    set logfile logs/npu_reset_${scenario}.log
    transcript file $logfile
    set plusarg {}
    if {$scenario eq "compute"} {set plusarg {+RESET_DURING_COMPUTE}}
    if {$scenario eq "drain"} {set plusarg {+RESET_DURING_DRAIN}}
    vsim -onfinish stop -sv_seed 1 -sv_lib $dpi ${lib}.tb_npu_nxn {*}$plusarg
    run 1 ms
    quit -sim
    transcript off
    set fh [open $logfile r]
    set result [read $fh]
    close $fh
    set completed 141
    set aborted 1
    if {$scenario eq "baseline"} {set completed 142; set aborted 0}
    set expected "requested=142 expected_completed=$completed completed=$completed expected_aborted=$aborted aborted=$aborted mismatches=0 pending_in=0 pending_out=0"
    set ok [expr {[string first $expected $result] >= 0 &&
        [regexp {UVM_ERROR\s*:\s*0\M} $result] &&
        [regexp {UVM_FATAL\s*:\s*0\M} $result] &&
        ![regexp {\*\* (Error|Fatal):} $result]}]
    transcript on
    if {!$ok} {error "NPU $scenario FAIL or incomplete: inspect $logfile"}
    puts "NPU_RESET_RESULT $scenario PASS completed=$completed aborted=$aborted"
}
puts "NPU reset regression finished; logs/npu_reset_*.log contain evidence."
