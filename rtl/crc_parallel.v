// =============================================================================
// Module      : crc16_parallel
// Description : High-performance parallel CRC-16 engine (byte-wide, 8 bits/cycle).
//               Equivalent to running crc_core serially 8 times, but unrolled
//               into a flat combinational gate chain — no iterative hardware.
//
// Algorithm:
//   For i = 0 to 7 (MSB-first: processes data_in[7] first, data_in[0] last):
//     feedback = next[15] XOR data_in[7-i]
//     next     = {next[14:0], 1'b0}
//     if (feedback) next = next XOR 16'h1021
//   crc <= next
//
// Performance:
//   Throughput: 8 bits per clock cycle (vs 1 bit/cycle for crc_core.v)
//   Latency:    1 clock cycle per byte
//
// REVIEW NOTE [v2]:
//   - `integer i` inside an always block is legal in Verilog-2001 and is
//     unrolled at compile time. All synthesizers (Vivado, Quartus, DC)
//     handle this correctly for constant loop bounds.
//   - `reg feedback` inside always block correctly synthesizes to a wire
//     per unrolled iteration — no flip-flops inferred for feedback or next.
//   - Only output `crc` maps to 16 flip-flops.
//   - INIT value is 0xFFFF for byte-stream CRC-CCITT use; can be changed
//     to 0x0000 if integrating with crc_top's frame-based computation.
//   - No functional changes required.
//
// Ports:
//   clk     : Rising-edge system clock
//   rst     : Synchronous active-HIGH reset (initializes CRC to 0xFFFF)
//   valid   : Process data_in when HIGH; hold CRC when LOW
//   data_in : 8-bit input byte (bit[7] = MSB, processed first)
//   crc     : 16-bit running CRC output
//
// Polynomial : 0x1021 (CRC-CCITT / 3GPP CRC-16, TS 38.212)
// Init       : 0xFFFF (standard CCITT; change to 0x0000 to match crc_core.v)
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc16_parallel (
    input  wire        clk,      // Rising-edge system clock
    input  wire        rst,      // Synchronous reset (active HIGH)
    input  wire        valid,    // Byte-valid: process data_in when HIGH
    input  wire [7:0]  data_in,  // 8-bit input byte, MSB-first
    output reg  [15:0] crc       // 16-bit CRC output register
);

    localparam [15:0] POLY     = 16'h1021; // CRC-CCITT polynomial
    localparam [15:0] CRC_INIT = 16'hFFFF; // Standard initial value

    // 'next' and 'feedback' are combinational intermediates inside the always block.
    // They are declared as reg only because Verilog requires it for always-block
    // assignments; they synthesize to pure combinational logic (no flip-flops).
    reg [15:0] next;
    reg        feedback;
    integer    i;

    always @(posedge clk) begin
        if (rst) begin
            crc <= CRC_INIT;        // Reset to 0xFFFF
        end
        else if (valid) begin
            next = crc;             // Seed combinational chain from registered CRC

            // Unroll 8 LFSR steps — synthesized as a flat gate chain
            for (i = 0; i < 8; i = i + 1) begin
                feedback = next[15] ^ data_in[7 - i];  // Tap: MSB XOR current input bit
                next     = {next[14:0], 1'b0};          // Shift left, clear LSB
                if (feedback)
                    next = next ^ POLY;                  // Apply polynomial if feedback=1
            end

            crc <= next;            // Register the 8-step result (only FF assignment)
        end
        // else: valid=0 → crc holds, no latch (synchronous design)
    end

endmodule
// =============================================================================
// END OF MODULE: crc16_parallel
// =============================================================================
