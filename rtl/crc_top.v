// =============================================================================
// Module      : crc_top
// Description : Top-level 5G NR CRC generator module.
//               Accepts a 32-bit parallel data word, serializes it MSB-first
//               over 32 clock cycles, and simultaneously drives four CRC
//               cores (CRC16, CRC24A, CRC24B, CRC24C).
//
// Operation:
//   1. Assert 'start' for one clock cycle to latch 'data' and begin.
//   2. The shift register serializes data[31] first down to data[0].
//   3. All four CRC cores receive the same bit stream in parallel.
//   4. After exactly 32 cycles, 'done' pulses HIGH for one cycle.
//   5. CRC outputs are stable from 'done' onward until next 'start'.
//
// Port Summary:
//   clk    : System clock (rising edge triggered)
//   rst    : Synchronous reset, active HIGH — resets all state and CRCs
//   start  : One-cycle pulse to latch data and begin computation
//   data   : 32-bit input data word (parallel, MSB = data[31] sent first)
//   crc16  : 16-bit CRC output (polynomial 0x1021)
//   crc24a : 24-bit CRC output (polynomial 0x864CFB)
//   crc24b : 24-bit CRC output (polynomial 0x800063)
//   crc24c : 24-bit CRC output (polynomial 0x4C11DB)
//   done   : One-cycle HIGH pulse when all 32 bits have been processed
//   busy   : HIGH while processing is in progress
//
// Compatibility:
//   Designed to directly instantiate crc_core.v:
//     - Synchronous reset, active HIGH
//     - 'valid' driven by 'processing' flag
//     - 'data_in' driven by MSB of shift register
//     - INIT = all zeros (3GPP TS 38.212 Section 5.1)
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc_top (
    input  wire        clk,    // Rising-edge system clock
    input  wire        rst,    // Synchronous reset (active HIGH)
    input  wire        start,  // Start pulse — hold HIGH for exactly 1 cycle
    input  wire [31:0] data,   // 32-bit parallel data input

    output wire [15:0] crc16,  // CRC-16  result (poly=0x1021)
    output wire [23:0] crc24a, // CRC-24A result (poly=0x864CFB)
    output wire [23:0] crc24b, // CRC-24B result (poly=0x800063)
    output wire [23:0] crc24c, // CRC-24C result (poly=0x4C11DB)
    output reg         done,   // 1-cycle pulse when computation completes
    output wire        busy    // HIGH during active processing
);

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // Shift register: holds the 32-bit data and shifts left each cycle.
    // MSB (bit 31) is the serial output — sent to all CRC cores.
    reg [31:0] shift_reg;

    // Bit counter: counts from 0 to 31, one count per clock when processing.
    // Using 5 bits: counts 0–31 (needs to represent 31 = 5'b11111).
    reg [4:0] bit_cnt;

    // Processing flag: HIGH while serialization is in progress.
    reg processing;

    // Reset signal for CRC cores — asserted synchronously on top-level rst
    // or when a new 'start' pulse is received (to re-initialize each run).
    reg crc_rst;

    // =========================================================================
    // Continuous Assignments
    // =========================================================================

    // 'busy' reflects the processing state combinationally.
    assign busy = processing;

    // =========================================================================
    // Control FSM: Serialize & Count
    // =========================================================================
    // States:
    //   IDLE (processing=0): Waiting for 'start' pulse.
    //   ACTIVE (processing=1): Shifting data, counting bits, feeding CRC cores.
    //   On bit_cnt reaching 31: deassert processing, pulse done.
    // =========================================================================

    always @(posedge clk) begin
        if (rst) begin
            // -----------------------------------------------------------------
            // Synchronous reset: clear all control registers
            // -----------------------------------------------------------------
            shift_reg  <= 32'h0;
            bit_cnt    <= 5'd0;
            processing <= 1'b0;
            done       <= 1'b0;
            crc_rst    <= 1'b1;  // Hold CRC cores in reset
        end
        else begin
            // Default: done is a one-cycle pulse, de-assert each cycle
            done    <= 1'b0;
            crc_rst <= 1'b0; // Release CRC cores from reset (unless start re-triggers)

            if (start && !processing) begin
                // -------------------------------------------------------------
                // START: Latch data, reset bit counter, begin processing.
                // crc_rst is asserted for THIS cycle so CRC cores re-initialize.
                // Processing begins on the NEXT rising edge.
                // -------------------------------------------------------------
                shift_reg  <= data;
                bit_cnt    <= 5'd0;
                processing <= 1'b1;
                crc_rst    <= 1'b1; // Re-initialize CRC cores for new computation
            end
            else if (processing) begin
                // -------------------------------------------------------------
                // ACTIVE: Shift one bit, increment counter, feed CRC cores.
                // The MSB of shift_reg (shift_reg[31]) is the current serial bit.
                // Advance shift register left — next MSB becomes next serial bit.
                // -------------------------------------------------------------
                shift_reg <= shift_reg << 1;  // Shift left: shift_reg[31] consumed
                bit_cnt   <= bit_cnt + 5'd1;

                if (bit_cnt == 5'd31) begin
                    // ---------------------------------------------------------
                    // All 32 bits processed. Stop and signal completion.
                    // ---------------------------------------------------------
                    processing <= 1'b0;
                    done       <= 1'b1; // One-cycle completion pulse
                end
            end
        end
    end

    // =========================================================================
    // CRC Core Instantiations
    // =========================================================================
    // All four cores receive:
    //   clk     = system clock
    //   rst     = crc_rst (reset on top-level reset OR on new 'start')
    //   valid   = processing (only shift LFSR while actively processing)
    //   data_in = shift_reg[31] (current MSB = current serial bit)
    //
    // Note: shift_reg[31] is captured at the posedge of each clock.
    //       Since 'processing' goes HIGH the cycle AFTER 'start' (due to the
    //       sequential assignment), shift_reg[31] correctly holds data[31]
    //       on the first valid cycle.
    // =========================================================================

    // -------------------------------------------------------------------------
    // CRC-16: Polynomial = 0x1021, Width = 16 bits
    // Used for: UL-SCH, DL-SCH transport block CRC in LTE/NR
    // -------------------------------------------------------------------------
    crc_core #(
        .WIDTH (16         ),
        .POLY  (16'h1021   ),
        .INIT  (16'h0000   )
    ) u_crc16 (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc16         )
    );

    // -------------------------------------------------------------------------
    // CRC-24A: Polynomial = 0x864CFB, Width = 24 bits
    // Used for: Transport block CRC attachment (large blocks)
    // -------------------------------------------------------------------------
    crc_core #(
        .WIDTH (24         ),
        .POLY  (24'h864CFB ),
        .INIT  (24'h000000 )
    ) u_crc24a (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc24a        )
    );

    // -------------------------------------------------------------------------
    // CRC-24B: Polynomial = 0x800063, Width = 24 bits
    // Used for: Code block CRC attachment (LDPC BG1/BG2 segmentation)
    // -------------------------------------------------------------------------
    crc_core #(
        .WIDTH (24         ),
        .POLY  (24'h800063 ),
        .INIT  (24'h000000 )
    ) u_crc24b (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc24b        )
    );

    // -------------------------------------------------------------------------
    // CRC-24C: Polynomial = 0x4C11DB, Width = 24 bits
    // Used for: SI message CRC in NR (3GPP TS 38.212 Section 7.3.2)
    // -------------------------------------------------------------------------
    crc_core #(
        .WIDTH (24         ),
        .POLY  (24'h4C11DB ),
        .INIT  (24'h000000 )
    ) u_crc24c (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc24c        )
    );

endmodule

// =============================================================================
// END OF MODULE: crc_top
// =============================================================================
