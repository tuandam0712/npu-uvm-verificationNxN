do scripts/compile.do
transcript file logs/uvm_run.log
vsim work.tb_npu_nxn
run -all
quit -sim