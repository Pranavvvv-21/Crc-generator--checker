// =============================================================================
// Module      : crc16_parallel
// Description : High-performance parallel CRC-16 engine for 5G NR systems.
//               Processes 8 bits per clock cycle (byte-wide input).
//               Equivalent to running crc_core.v 8 times per cycle but
//               implemented as a fully unrolled combinational loop —
//               synthesizes to a flat gate network with no feedback registers
//               in the datapath (only the output register is sequential).
//
// Performance Comparison:
//   crc_core.v (serial)   : 1 bit  per clock → 8x slower for byte-wide data
//   crc16_parallel.v      : 8 bits per clock → 8x throughput improvement
//   Latency               : 1 clock cycle per byte (purely pipelined)
//
// Algorithm:
//   For each of the 8 bits in data_in (MSB = bit 7 processed first):
//     feedback = crc[15] XOR data_in[7-i]
//     crc      = {crc[14:0], 1'b0}
//     if (feedback) crc = crc XOR 16'h1021
//
//   This is mathematically equivalent to the LFSR serial algorithm run 8
//   times in sequence — NOT a lookup table approximation.
//
// Ports:
//   clk      : Rising-edge system clock
//   rst      : Synchronous reset, active HIGH → CRC initializes to 0xFFFF
//   valid    : Byte-valid signal — process data_in when HIGH
//   data_in  : 8-bit input data byte (bit[7] is MSB, processed first)
//   crc      : 16-bit running CRC output (stable one cycle after valid)
//
// Polynomial : 0x1021 (CRC-CCITT, as used in 3GPP TS 38.212 CRC-16)
// Init Value : 0xFFFF (standard CCITT initialization)
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc16_parallel (
    input  wire        clk,      // Rising-edge system clock
    input  wire        rst,      // Synchronous reset, active HIGH
    input  wire        valid,    // Data byte valid — shift CRC only when HIGH
    input  wire [7:0]  data_in,  // 8-bit input data (bit[7] = MSB, first)
    output reg  [15:0] crc       // 16-bit CRC output register
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam [15:0] POLY     = 16'h1021; // CRC-CCITT / 3GPP CRC-16 polynomial
    localparam [15:0] CRC_INIT = 16'hFFFF; // Standard CRC-16 initial value

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // 'next' holds the running CRC value as we iterate through all 8 bits
    // combinationally within a single always block.
    // It is a reg here because it is assigned inside an always block, but it
    // synthesizes entirely to combinational logic (no flip-flops) —
    // only 'crc' (the output reg) maps to actual flip-flops.
    reg [15:0] next;

    // Loop variable: iterates 0..7 to process each bit of data_in.
    integer i;

    // Per-iteration feedback bit (declared as reg because it's used inside
    // an always block — synthesizes to a single wire per unrolled iteration).
    reg feedback;

    // =========================================================================
    // Parallel CRC Logic (Synchronous)
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // -----------------------------------------------------------------
            // Synchronous Reset: load CRC init value
            // -----------------------------------------------------------------
            crc <= CRC_INIT;
        end
        else if (valid) begin
            // -----------------------------------------------------------------
            // Active processing: unroll 8 LFSR iterations combinationally.
            //
            // 'next' starts as the current CRC register value.
            // Each loop iteration applies one bit of data_in MSB-first,
            // updating 'next' in place — exactly as a real serial LFSR would
            // update its register 8 times in 8 clock cycles, but here all 8
            // steps are resolved combinationally in a single cycle.
            //
            // Synthesis will unroll this loop at compile time into a flat
            // gate network — no actual loop hardware is generated.
            // -----------------------------------------------------------------
            next = crc; // Seed the combinational chain with the stored CRC

            for (i = 0; i < 8; i = i + 1) begin
                // Step 1: Compute feedback for this iteration
                //   feedback = MSB of running CRC XOR current input bit
                //   MSB-first ordering: process data_in[7], [6], ... [0]
                feedback = next[15] ^ data_in[7 - i];

                // Step 2: Shift the running CRC left by one position
                //   Vacate LSB with 0 (standard LFSR left shift)
                next = {next[14:0], 1'b0};

                // Step 3: Conditionally XOR with polynomial
                //   Apply only if feedback = 1 (standard LFSR division step)
                //   This is identical to the crc_core.v LFSR logic — just
                //   run 8 times in sequence within one always block.
                if (feedback)
                    next = next ^ POLY;
            end

            // -----------------------------------------------------------------
            // Register the final result of all 8 iterations.
            // This is the only flip-flop assignment — 'next' itself is
            // purely combinational within this always block.
            // -----------------------------------------------------------------
            crc <= next;
        end
        // else: valid = 0 → crc holds its current value (no latch — synchronous hold)
    end

endmodule

// =============================================================================
// END OF MODULE: crc16_parallel
// =============================================================================
