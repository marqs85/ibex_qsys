module fifo_v2 #(
  parameter  WIDTH,
  parameter  DEPTH
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  input  logic             testmode_i,

  input  logic             flush_i,
  output logic             full_o,
  output logic             empty_o,
  output logic             alm_full_o,
  output logic             alm_empty_o,
  input [(WIDTH-1):0]      data_i,
  input logic              push_i,
  output [(WIDTH-1):0]     data_o,
  input logic              pop_i
);

localparam int Aw              = $clog2(DEPTH);  // derived parameter

dcfifo dcfifo_component (
            .data (data_i),
            .rdclk (clk_i),
            .rdreq (pop_i),
            .wrclk (clk_i),
            .wrreq (push_i),
            .q (data_o),
            .rdempty (empty_o),
            .rdusedw (),
            .wrfull (full_o),
            .aclr (),
            .eccstatus (),
            .rdfull (),
            .wrempty (),
            .wrusedw ());
defparam
    dcfifo_component.add_usedw_msb_bit = "ON",
    dcfifo_component.intended_device_family = "Cyclone V",
    dcfifo_component.lpm_numwords = DEPTH,
    dcfifo_component.lpm_showahead = "ON",
    dcfifo_component.lpm_type = "dcfifo",
    dcfifo_component.lpm_width = WIDTH,
    dcfifo_component.overflow_checking = "ON",
    dcfifo_component.rdsync_delaypipe = 4,
    dcfifo_component.underflow_checking = "ON",
    dcfifo_component.use_eab = "ON",
    dcfifo_component.wrsync_delaypipe = 4;

endmodule
