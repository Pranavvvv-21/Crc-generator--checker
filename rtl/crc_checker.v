// =============================================================================
// Module      : crc_checker
// Description : Combinational CRC integrity checker for 5G NR CRC Engine.
//               Verifies that computed CRC values are zero after appending
//               the CRC bits to the data stream (standard CRC check method).
//
// Operation:
//   In a valid CRC check scenario, the receiver appends the received CRC
//   bits back into the same LFSR pipeline. If there are no errors, the
//   resulting CRC register value is 0x000...0 for all variants.
//   Any non-zero CRC value indicates a corrupted data block.
//
// Logic:
//   error = 1  if (crc16 != 0) OR (crc24a != 0) OR (crc24b != 0) OR (crc24c != 0)
//   error = 0  if all CRC outputs are exactly zero
//
// Ports:
//   crc16  : 16-bit CRC value from CRC-16  engine (poly 0x1021)
//   crc24a : 24-bit CRC value from CRC-24A engine (poly 0x864CFB)
//   crc24b : 24-bit CRC value from CRC-24B engine (poly 0x800063)
//   crc24c : 24-bit CRC value from CRC-24C engine (poly 0x4C11DB)
//   error  : 1 = error detected in at least one CRC variant
//            0 = all CRC values are zero (data integrity confirmed)
//
// Note:
//   This module is purely combinational — no clk or rst required.
//   Output 'error' updates immediately whenever any input changes.
//   Safe to wire directly to the outputs of crc_top.
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc_checker (
    input  wire [15:0] crc16,   // CRC-16  result from crc_top
    input  wire [23:0] crc24a,  // CRC-24A result from crc_top
    input  wire [23:0] crc24b,  // CRC-24B result from crc_top
    input  wire [23:0] crc24c,  // CRC-24C result from crc_top
    output wire        error    // 1 = error detected, 0 = data integrity OK
);

    // =========================================================================
    // Error Detection Logic (Combinational)
    // =========================================================================
    // An OR-reduction of each CRC value tells us if ANY bit is non-zero.
    // All four checks are OR'd together — if even one CRC variant is non-zero,
    // the entire block is flagged as corrupted.
    //
    // Using wire assignment (not always block) to keep this purely
    // combinational and infer no latches.
    // =========================================================================

    assign error = (|crc16)   |   // OR-reduce: 1 if any bit of crc16  is non-zero
                   (|crc24a)  |   // OR-reduce: 1 if any bit of crc24a is non-zero
                   (|crc24b)  |   // OR-reduce: 1 if any bit of crc24b is non-zero
                   (|crc24c);     // OR-reduce: 1 if any bit of crc24c is non-zero

endmodule

// =============================================================================
// END OF MODULE: crc_checker
// =============================================================================
