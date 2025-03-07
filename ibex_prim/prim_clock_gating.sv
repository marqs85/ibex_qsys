// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Common Library: Clock Gating cell
//
// The logic assumes that en_i is synchronized (so the instantiation site might need to put a
// synchronizer before en_i).

module prim_clock_gating #(
  parameter bit NoFpgaGate = 1'b0, // this parameter has no function in generic
  parameter bit FpgaBufGlobal = 1'b1 // this parameter has no function in generic
) (
  input        clk_i,
  input        en_i,
  input        test_en_i,
  output logic clk_o
);

assign clk_o = clk_i; // no gate for FPGA

endmodule
