`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  sarr_formal UUT (

  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    UUT._witness_.anyinit_procdff_271 = 1'b0;
    UUT._witness_.anyinit_procdff_273 = 1'b0;
    UUT._witness_.anyinit_procdff_275 = 1'b0;
    UUT._witness_.anyinit_procdff_277 = 1'b0;
    UUT._witness_.anyinit_procdff_279 = 1'b0;
    UUT._witness_.anyinit_procdff_281 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_284 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_285 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_286 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_287 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_288 = 4'b1111;
    UUT.dut._witness_.anyinit_procdff_289 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_290 = 4'b0001;
    UUT.dut._witness_.anyinit_procdff_291 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_292 = 4'b1000;
    UUT.dut._witness_.anyinit_procdff_293 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_294 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_295 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_296 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_297 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_298 = 4'b1000;
    UUT.dut._witness_.anyinit_procdff_299 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_300 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_301 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_302 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_303 = 4'b0000;
    UUT.dut.\pe_rows[0] .\pe_cols[0] .u_pe._witness_.anyinit_procdff_270 = 9'b000000000;
    // UUT.dut.\pe_rows[0] .\pe_cols[1] .u_pe.$auto$async2sync.\cc:171:execute$352  = 9'b000000000;
    // UUT.dut.\pe_rows[1] .\pe_cols[0] .u_pe.$auto$async2sync.\cc:171:execute$350  = 9'b000000000;
    // UUT.dut.\pe_rows[1] .\pe_cols[1] .u_pe.$auto$async2sync.\cc:171:execute$348  = 9'b100000001;
    UUT.past_valid = 1'b0;
    UUT.a_in[1'b1] = 4'b0000;
    UUT.a_in[1'b0] = 4'b0000;
    UUT.b_in[1'b1] = 4'b0000;
    UUT.b_in[1'b0] = 4'b0000;

    // state 0
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
    end

    // state 2
    if (cycle == 1) begin
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
