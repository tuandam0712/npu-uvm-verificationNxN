file mkdir reports

do scripts/compile.do

transcript file reports/cov_run.log

vsim -coverage work.tb_npu_nxn
run -all
coverage save uvm_normal.ucdb
quit -sim

vsim -coverage work.tb_rtl_random
run -all
coverage save reset_abort.ucdb
quit -sim

vcover merge full_cov.ucdb uvm_normal.ucdb reset_abort.ucdb

vcover report -details -output reports/full_coverage_report.txt full_cov.ucdb
vcover report -totals  -output reports/full_coverage_summary.txt full_cov.ucdb

puts "Coverage closure completed."