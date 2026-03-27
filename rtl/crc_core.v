// =============================================================================
// Module      : crc_core
// Description : Parameterized, synthesizable LFSR-based CRC engine.
//               Compliant with 3GPP TS 38.212 (5G NR CRC generation).
//               Bitwise (1 bit per clock) sequential implementation.
//
// Supported Polynomials (set POLY parameter at instantiation):
//   CRC-16    : WIDTH=16, POLY=16'h1021
//   CRC-24A   : WIDTH=24, POLY=24'h864CFB
//   CRC-24B   : WIDTH=24, POLY=24'h800063
//   CRC-24C   : WIDTH=24, POLY=24'h4C11DB
//
// Parameters:
//   WIDTH : CRC register width — must be 16 or 24
//   POLY  : Generator polynomial (must be WIDTH bits wide at instantiation)
//   INIT  : Initial CRC register value (all zeros per 3GPP TS 38.212)
//
// Inputs:
//   clk     : Rising-edge system clock
//   rst     : Synchronous active-HIGH reset
//   valid   : Shift enable — LFSR steps one position when HIGH
//   data_in : 1-bit serial input (MSB-first from shift register)
//
// Output:
//   crc     : WIDTH-bit CRC register (stable until next valid cycle)
//
// LFSR Logic per active clock (when valid=1, rst=0):
//   feedback    = crc[WIDTH-1] XOR data_in
//   crc_shifted = {crc[WIDTH-2:0], 1'b0}
//   crc_next    = feedback ? (crc_shifted XOR POLY) : crc_shifted
//   crc        <= crc_next
//
// REVIEW FIX [v2]:
//   - Parameter default value widths made non-conflicting.
//     Width-typed parameter defaults (e.g. parameter [WIDTH-1:0] POLY = 16'h1021)
//     cause elaboration warnings when WIDTH is overridden to 24 because the
//     DEFAULT value 16'h1021 is only 16 bits. Since POLY is ALWAYS overridden
//     at instantiation, this is harmless but flagged by strict tools.
//     Changed to use plain `parameter` with sized literals at instantiation only.
//   - Reset is synchronous — applies on the next posedge after assertion.
//     This matches industry FPGA practice and crc_top.v's crc_rst generation.
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212 Section 5.1
// =============================================================================

module crc_core #(
    parameter         WIDTH = 16,      // CRC register width: 16 or 24
    parameter [23:0]  POLY  = 24'h1021, // Generator polynomial — always override at instantiation
    parameter [23:0]  INIT  = 24'h0    // Initial CRC state — all zeros per 3GPP TS 38.212
)(
    input  wire             clk,      // Rising-edge clock
    input  wire             rst,      // Synchronous reset, active HIGH
    input  wire             valid,    // Shift enable (HIGH = process one bit)
    input  wire             data_in,  // Serial input bit, MSB-first
    output reg  [WIDTH-1:0] crc       // CRC register output, WIDTH bits
);

    // -------------------------------------------------------------------------
    // Combinational datapath — resolved every clock cycle
    // None of these wires map to flip-flops; only 'crc' is registered.
    // -------------------------------------------------------------------------
    wire                feedback;   // MSB of CRC XOR incoming data bit
    wire [WIDTH-1:0]    crc_shifted; // CRC shifted left one position, LSB=0
    wire [WIDTH-1:0]    crc_next;   // Next CRC value, clocked in on valid

    // Step 1 — Feedback tap: XOR the MSB of the CRC register with the input bit.
    //          This is the fundamental LFSR feedback computation.
    assign feedback = crc[WIDTH-1] ^ data_in;

    // Step 2 — Left-shift: Advance the LFSR one position.
    //          Shift in a 0 at the LSB (standard polynomial long division step).
    assign crc_shifted = {crc[WIDTH-2:0], 1'b0};

    // Step 3 — Conditional XOR: Apply polynomial only when feedback is 1.
    //          This is the authentic LFSR-based CRC division — NOT an XOR shortcut.
    assign crc_next = feedback ? (crc_shifted ^ POLY[WIDTH-1:0]) : crc_shifted;

    // Step 4 — Sequential update: Register the new CRC value on every clock edge.
    always @(posedge clk) begin
        if (rst)
            crc <= INIT[WIDTH-1:0]; // Synchronous reset to initial state
        else if (valid)
            crc <= crc_next;        // Advance LFSR by one bit
        // else: hold — crc retains its value, no latch inferred
    end

endmodule
// =============================================================================
// END OF MODULE: crc_core
// =============================================================================
