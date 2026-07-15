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
  controller_formal UUT (

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
    UUT._witness_.anyinit_procdff_115 = 3'b010;
    UUT._witness_.anyinit_procdff_116 = 1'b1;
    UUT._witness_.anyinit_procdff_117 = 1'b0;
    UUT._witness_.anyinit_procdff_119 = 1'b1;
    UUT._witness_.anyinit_procdff_121 = 1'b0;
    UUT._witness_.anyinit_procdff_123 = 1'b0;
    UUT._witness_.anyinit_procdff_125 = 1'b0;
    UUT._witness_.anyinit_procdff_127 = 1'b1;
    UUT._witness_.anyinit_procdff_129 = 1'b0;
    UUT._witness_.anyinit_procdff_131 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_112 = 3'b010;
    UUT.dut._witness_.anyinit_procdff_113 = 6'b001000;
    UUT.dut._witness_.anyinit_procdff_114 = 6'b000000;
    UUT.past_valid = 1'b0;

    // state 0
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
    end

    genclock <= cycle < 1;
    cycle <= cycle + 1;
  end
endmodule
