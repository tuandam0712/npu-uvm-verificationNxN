# Run from repo root: do scripts/run_npu_reset.do [all|baseline|compute|drain] [seed|sweep]
# sweep = seeds 1..5. Compile once; preserve a separate log for each case/seed.
# Dedicated library avoids deleting APB or other work libraries.
onerror {quit -f -code 1}
set mode all
if {$argc > 0} {set mode $1}
if {$mode ni {all baseline compute drain}} {error "Use all, baseline, compute, or drain"}
set modes [list $mode]
if {$mode eq "all"} {set modes {baseline compute drain}}
set seed_arg 1
if {$argc > 1} {set seed_arg $2}
if {$seed_arg eq "sweep"} {
    set seeds {1 2 3 4 5}
} else {
    if {![string is integer -strict $seed_arg] || $seed_arg < 1 || $seed_arg > 2147483647} {
        error "Seed must be 1..2147483647 or sweep"
    }
    set seeds [list $seed_arg]
}
file mkdir logs
file mkdir reports
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

set summary_path reports/npu_multiseed_summary.csv
set summary [open $summary_path w]
puts $summary "case,seed,status,completed,aborted,input_coverage,matrix_coverage,log"
flush $summary
set failures 0
set runs 0
foreach seed $seeds {
foreach scenario $modes {
    set logfile logs/npu_reset_${scenario}_seed${seed}.log
    transcript off
    # Never let a previous PASS in an old log hide a failed/incomplete rerun.
    close [open $logfile w]
    transcript file $logfile
    transcript on
    set plusarg {}
    if {$scenario eq "compute"} {set plusarg {+RESET_DURING_COMPUTE}}
    if {$scenario eq "drain"} {set plusarg {+RESET_DURING_DRAIN}}
    vsim -onfinish stop -sv_seed $seed -sv_lib $dpi ${lib}.tb_npu_nxn {*}$plusarg
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
    set observed_completed -1
    set observed_aborted -1
    set input_cov NA
    set matrix_cov NA
    regexp {requested=142 expected_completed=[0-9]+ completed=([0-9]+) expected_aborted=[0-9]+ aborted=([0-9]+)} $result -> observed_completed observed_aborted
    regexp {in data cov = ([0-9.]+)%, mat pattern cov = ([0-9.]+)%} $result -> input_cov matrix_cov
    set ok [expr {[string first $expected $result] >= 0 &&
        [regexp {UVM_ERROR\s*:\s*0\M} $result] &&
        [regexp {UVM_FATAL\s*:\s*0\M} $result] &&
        ![regexp {UVM_(ERROR|FATAL)[ \t]+[^ \t:\r\n]} $result] &&
        ![regexp {\*\* (Error|Fatal):} $result]}]
    transcript on
    set status PASS
    if {!$ok} {set status FAIL; incr failures}
    incr runs
    puts $summary "$scenario,$seed,$status,$observed_completed,$observed_aborted,$input_cov,$matrix_cov,$logfile"
    flush $summary
    puts "NPU_RESET_RESULT $scenario seed=$seed $status completed=$observed_completed aborted=$observed_aborted"
}
}
close $summary
puts "NPU_REGRESSION_SUMMARY runs=$runs passed=[expr {$runs-$failures}] failed=$failures report=$summary_path"
if {$failures > 0} {error "NPU regression failed; inspect $summary_path"}
