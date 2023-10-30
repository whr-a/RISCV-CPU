`timescale 1ns / 1ps
`include "iFetch.v"
`include "SetSize.v"
module cpu(
  input  wire                 clk_in,     // system clock signal
  input  wire                 rst_in,     // reset signal
  input  wire                 rdy_in,     // ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,    // data input bus
  output wire [ 7:0]          mem_dout,   // data output bus
  output wire [31:0]          mem_a,      // address bus (only 17:0 is used)//todo
  output wire                 mem_wr,     // write/read signal (1 for write)//todo
  
  input  wire                 io_buffer_full, // 1 if uart buffer is full
  
  output wire [31:0]      dbgreg_dout   // cpu register output (debugging demo)//todo
);

endmodule
