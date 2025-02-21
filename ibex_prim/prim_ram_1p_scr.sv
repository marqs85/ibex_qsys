// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// This is a draft implementation of a low-latency memory scrambling mechanism.
//
// The module is implemented as a primitive, in the same spirit as similar prim_ram_1p_adv wrappers.
// Hence, it can be conveniently instantiated by comportable IPs (such as OTBN) or in top_earlgrey
// for the main system memory.
//
// The currently implemented architecture uses a reduced-round PRINCE cipher primitive in CTR mode
// in order to (weakly) scramble the data written to the memory macro. Plain CTR mode does not
// diffuse the data since the keystream is just XOR'ed onto it, hence we also we perform byte-wise
// diffusion using a (shallow) substitution/permutation network layers in order to provide a limited
// avalanche effect within a byte.
//
// In order to break the linear addressing space, the address is passed through a bijective
// scrambling function constructed using a (shallow) substitution/permutation and a nonce. Due to
// that nonce, the address mapping is not fully baked into RTL and can be changed at runtime as
// well.
//
// See also: prim_cipher_pkg, prim_prince

`include "prim_assert.sv"

import prim_ram_1p_pkg::*;

module prim_ram_1p_scr #(
  parameter  int Depth               = 16*1024, // Needs to be a power of 2 if NumAddrScrRounds > 0.
  parameter  int Width               = 32, // Needs to be byte aligned if byte parity is enabled.
  parameter  int DataBitsPerMask     = 8, // Needs to be set to 8 in case of byte parity.
  parameter  bit EnableParity        = 1, // Enable byte parity.

  // Scrambling parameters. Note that this needs to be low-latency, hence we have to keep the
  // amount of cipher rounds low. PRINCE has 5 half rounds in its original form, which corresponds
  // to 2*5 + 1 effective rounds. Setting this to 3 lowers this to approximately 7 effective rounds.
  // Number of PRINCE half rounds, can be [1..5]
  parameter  int NumPrinceRoundsHalf = 3,
  // Number of extra diffusion rounds. Setting this to 0 to disables diffusion.
  // NOTE: this is zero by default, since the non-linear transformation of data bits can interact
  // adversely with end-to-end ECC integrity. Only enable this if you know what you are doing
  // (e.g. using this primitive in a different context with byte parity). See #20788 for context.
  parameter  int NumDiffRounds       = 0,
  // This parameter governs the block-width of additional diffusion layers.
  // For intra-byte diffusion, set this parameter to 8.
  parameter  int DiffWidth           = DataBitsPerMask,
  // Number of address scrambling rounds. Setting this to 0 disables address scrambling.
  parameter  int NumAddrScrRounds    = 2,
  // If set to 1, the same 64bit key stream is replicated if the data port is wider than 64bit.
  // If set to 0, the cipher primitive is replicated, and together with a wider nonce input,
  // a unique keystream is generated for the full data width.
  parameter  bit ReplicateKeyStream  = 1'b0
) (
  input                             clk_i,
  input                             rst_ni,

  // Key interface. Memory requests will not be granted if key_valid is set to 0.
  input                             key_valid_i,
  input        [128-1:0]   key_i,
  input        [(64 * ((ReplicateKeyStream) ? 1 : (Width + 63) / 64))-1:0]     nonce_i,

  // Interface to TL-UL SRAM adapter
  input                             req_i,
  output logic                      gnt_o,
  input                             write_i,
  input        [prim_util_pkg::vbits(Depth)-1:0]      addr_i,
  input        [Width-1:0]          wdata_i,
  input        [Width-1:0]          wmask_i,  // Needs to be byte-aligned for parity
  // On integrity errors, the primitive surpresses any real transaction to the memory.
  input                             intg_error_i,
  output logic [Width-1:0]          rdata_o,
  output logic                      rvalid_o, // Read response (rdata_o) is valid
  output logic [1:0]                rerror_o, // Bit1: Uncorrectable, Bit0: Correctable
  output logic [31:0]               raddr_o,  // Read address for error reporting.

  // config
  input ram_1p_cfg_t                cfg_i,

  // Write currently pending inside this module.
  output logic                      wr_collision_o,
  output logic                      write_pending_o,

  // When detecting multi-bit encoding errors, raise alert.
  output logic                      alert_o
);



endmodule : prim_ram_1p_scr
