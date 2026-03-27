// =============================================================================
// Module      : crc_checker
// Description : Combinational CRC integrity checker for 5G NR CRC Engine.
//
// In the standard CRC check procedure (receiver side):
//   The received data word PLUS its appended CRC bits are fed back through
//   the same LFSR pipeline used for generation. If no transmission errors
//   occurred, the LFSR register drains to exactly zero. A non-zero residue
//   means the received block is corrupted.
//
// This module flags an error if ANY of the four CRC variants is non-zero.
//
// Logic:
//   error = 0   iff crc16==0 AND crc24a==0 AND crc24b==0 AND crc24c==0
//   error = 1   otherwise (at least one variant has a non-zero residue)
//
// Implementation:
//   Uses Verilog bitwise OR-reduction (|signal) — synthesizes to a balanced
//   OR-gate tree. This is width-agnostic and infers NO latches because it is
//   a continuous assign (not an always block).
//
// REVIEW NOTE [v2]:
//   No changes required. The combinational assign with OR-reduction is
//   correct, synthesis-clean, and latch-free. Port names and widths match
//   crc_top.v exactly: crc16[15:0], crc24a/b/c[23:0].
//
// Ports:
//   crc16  : 16-bit result from CRC-16  engine (poly 0x1021)
//   crc24a : 24-bit result from CRC-24A engine (poly 0x864CFB)
//   crc24b : 24-bit result from CRC-24B engine (poly 0x800063)
//   crc24c : 24-bit result from CRC-24C engine (poly 0x4C11DB)
//   error  : 1 = integrity check failed; 0 = all CRCs are zero (data OK)
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc_checker (
    input  wire [15:0] crc16,   // CRC-16  residue from crc_top
    input  wire [23:0] crc24a,  // CRC-24A residue from crc_top
    input  wire [23:0] crc24b,  // CRC-24B residue from crc_top
    input  wire [23:0] crc24c,  // CRC-24C residue from crc_top
    output wire        error    // 1 = error detected, 0 = data integrity confirmed
);

    // =========================================================================
    // Error Detection — purely combinational, no clk/rst required
    // OR-reduce each CRC field, then OR all four results together.
    // Synthesizes to: OR-tree(crc16) | OR-tree(crc24a) | OR-tree(crc24b) | OR-tree(crc24c)
    // =========================================================================
    assign error = (|crc16)  |   // Non-zero CRC-16  → error
                   (|crc24a) |   // Non-zero CRC-24A → error
                   (|crc24b) |   // Non-zero CRC-24B → error
                   (|crc24c);    // Non-zero CRC-24C → error

endmodule
// =============================================================================
// END OF MODULE: crc_checker
// =============================================================================
