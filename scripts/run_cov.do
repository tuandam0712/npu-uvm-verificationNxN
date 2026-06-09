do scripts/compile.do
transcript file logs/cov_run.log
vsim -coverage work.tb_npu_nxn
run -all
coverage save uvm_normal.ucdb
quit -sim

vsim -coverage work.tb_rtl_random
run -all
coverage save reset_abort.ucdb
quit -sim

vcover merge full_cov.ucdb uvm_normal.ucdb reset_abort.ucdb

vcover report full_cov.ucdb
vcover report -details -output logs/full_coverage_report.txt full_cov.ucdb
puts "Coverage closure completed."