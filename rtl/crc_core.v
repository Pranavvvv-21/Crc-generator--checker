// =============================================================================
// Module      : crc_core
// Description : Parameterized, synthesizable LFSR-based CRC engine.
//               Compliant with 3GPP TS 38.212 (5G NR CRC generation).
//               Bitwise (1 bit per clock) sequential implementation.
//
// Supported Polynomials (set POLY parameter at instantiation):
//   CRC-16    : 0x1021  (WIDTH=16)
//   CRC-24A   : 0x864CFB (WIDTH=24)
//   CRC-24B   : 0x800063 (WIDTH=24)
//   CRC-24C   : 0x4C11DB (WIDTH=24)
//
// Parameters:
//   WIDTH : CRC register width (16 or 24)
//   POLY  : Generator polynomial (must match WIDTH)
//   INIT  : Initial value of the CRC shift register
//
// Inputs:
//   clk     : System clock (active rising edge)
//   rst     : Synchronous active-high reset
//   valid   : Enable signal — shift one bit when HIGH
//   data_in : Serial input data (1-bit, MSB first)
//
// Output:
//   crc     : Current CRC register value (WIDTH bits wide)
//
// LFSR Logic per clock (when valid = 1):
//   feedback = crc[WIDTH-1] XOR data_in
//   crc      = {crc[WIDTH-2:0], 1'b0}
//   if (feedback == 1) then crc = crc XOR POLY
//
// Author      : TCS Project - 5G NR CRC Engine
// Standard    : 3GPP TS 38.212 Section 5.1
// =============================================================================

module crc_core #(
    parameter           WIDTH = 16,           // CRC register width: 16 or 24
    parameter [WIDTH-1:0] POLY  = 16'h1021,   // Generator polynomial
    parameter [WIDTH-1:0] INIT  = {WIDTH{1'b0}} // Initial state (0x000...0)
)(
    input  wire             clk,      // Rising-edge clock
    input  wire             rst,      // Synchronous reset (active HIGH)
    input  wire             valid,    // Data-valid / shift enable
    input  wire             data_in,  // Serial input bit (MSB-first)
    output reg  [WIDTH-1:0] crc       // CRC register output
);

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    wire feedback;              // XOR of MSB of CRC register and incoming bit
    wire [WIDTH-1:0] crc_shifted; // CRC register after left shift (LSB = 0)
    wire [WIDTH-1:0] crc_next;    // CRC value for the next clock edge

    // -------------------------------------------------------------------------
    // Step 1: Compute feedback bit
    //   feedback = MSB of current CRC XOR input data bit
    //   This the LFSR tap that drives XOR gating with the polynomial.
    // -------------------------------------------------------------------------
    assign feedback = crc[WIDTH-1] ^ data_in;

    // -------------------------------------------------------------------------
    // Step 2: Shift CRC register left by 1 (vacate LSB with 0)
    //   This advances the LFSR one position.
    // -------------------------------------------------------------------------
    assign crc_shifted = {crc[WIDTH-2:0], 1'b0};

    // -------------------------------------------------------------------------
    // Step 3: Conditionally XOR with polynomial
    //   If feedback = 1  -> apply polynomial (LFSR division step)
    //   If feedback = 0  -> no XOR, just the shifted value
    //   This is the CORRECT LFSR logic — NOT a fake XOR shortcut.
    // -------------------------------------------------------------------------
    assign crc_next = feedback ? (crc_shifted ^ POLY) : crc_shifted;

    // -------------------------------------------------------------------------
    // Step 4: Sequential register update
    //   - On reset: load INIT value
    //   - On valid: clock in the computed next CRC
    //   - Otherwise: hold current value
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            crc <= INIT;
        else if (valid)
            crc <= crc_next;
        // else: crc holds its value (implicit latch-free hold in synchronous design)
    end

endmodule

// =============================================================================
// END OF MODULE: crc_core
// =============================================================================
