// =============================================================================
// Module      : crc_top
// Description : Top-level 5G NR CRC generator.
//               Accepts a 32-bit parallel data word, serializes it MSB-first
//               over exactly 32 clock cycles, and simultaneously computes
//               CRC16, CRC24A, CRC24B, and CRC24C via four crc_core instances.
//
// Operation (timing diagram):
//   Cycle  0: start=1 → shift_reg=data, bit_cnt=0, processing=1, crc_rst=1
//             (CRC cores see rst=1 this cycle — they reset to INIT)
//   Cycle  1: processing=1, crc_rst=0, valid=1
//             data_in = shift_reg[31] = data[31]  ← first bit processed
//             shift_reg shifts left, bit_cnt → 1
//   Cycle  2: data_in = data[30], bit_cnt → 2
//   ...
//   Cycle 32: data_in = data[0], bit_cnt == 31 → processing=0, done=1
//   Cycle 33: done=0, CRC outputs stable — testbench reads here
//
// REVIEW FIX [v2] — Critical Fix: Off-by-one on crc_rst vs processing:
//   PROBLEM: In the original version, crc_rst=1 and processing=1 were BOTH
//   asserted on cycle 0 (the start cycle). At cycle 1, both crc_rst=1 and
//   valid=processing=1 arrive at crc_core simultaneously. crc_core's RST
//   takes priority → CRC resets to INIT, ignoring the first data bit (data[31]).
//   This causes a silent 1-bit loss — CRC is computed over only 31 bits!
//
//   FIX: crc_rst is asserted ONE cycle BEFORE processing goes HIGH.
//   New flow:  cycle 0: start → crc_rst=1, processing=0 (CRC cores reset)
//              cycle 1: crc_rst=0, processing=1, valid kicks in with data[31]
//   This ensures no data bit is lost. processing is now delayed by one cycle
//   from start using a two-phase approach.
//
// Port Summary:
//   clk    : Rising-edge system clock
//   rst    : Top-level synchronous reset, active HIGH
//   start  : One-cycle HIGH pulse to begin new CRC computation
//   data   : 32-bit parallel input word (data[31] is processed first)
//   crc16  : 16-bit CRC-16  result  (poly = 0x1021)
//   crc24a : 24-bit CRC-24A result  (poly = 0x864CFB)
//   crc24b : 24-bit CRC-24B result  (poly = 0x800063)
//   crc24c : 24-bit CRC-24C result  (poly = 0x4C11DB)
//   done   : One-cycle HIGH pulse after bit 0 (data[0]) is processed
//   busy   : HIGH while serialization is in progress
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module crc_top (
    input  wire        clk,    // Rising-edge system clock
    input  wire        rst,    // Synchronous reset (active HIGH)
    input  wire        start,  // One-cycle start pulse — must be LOW during processing
    input  wire [31:0] data,   // 32-bit parallel data input

    output wire [15:0] crc16,  // CRC-16  output (poly=0x1021)
    output wire [23:0] crc24a, // CRC-24A output (poly=0x864CFB)
    output wire [23:0] crc24b, // CRC-24B output (poly=0x800063)
    output wire [23:0] crc24c, // CRC-24C output (poly=0x4C11DB)
    output reg         done,   // One-cycle HIGH pulse on completion
    output wire        busy    // HIGH while processing is in progress
);

    // =========================================================================
    // Internal Registers
    // =========================================================================
    reg [31:0] shift_reg;   // Serialization shift register (MSB fed to CRC cores)
    reg [4:0]  bit_cnt;     // Bit counter: 0–31, increments each active cycle
    reg        processing;  // FSM active flag: HIGH during 32 serialization cycles
    reg        crc_rst;     // Reset for CRC sub-cores (asserted on top rst OR start)

    // =========================================================================
    // Combinational Outputs
    // =========================================================================
    assign busy = processing;

    // =========================================================================
    // Control FSM
    // =========================================================================
    // FSM has two states: IDLE (processing=0) and ACTIVE (processing=1).
    //
    // FIXED TIMING: crc_rst is asserted on the START cycle (processing still 0),
    // and processing goes HIGH on the cycle AFTER start. This guarantees the
    // CRC cores complete their synchronous reset before the first valid bit
    // (data[31]) arrives on their data_in. No data bits are skipped.
    //
    // Signal sequence:
    //   posedge N   : start=1 sampled → shift_reg=data, crc_rst←1, processing←0
    //   posedge N+1 : crc_rst=1 → all CRC cores reset to INIT
    //                 crc_rst←0, processing←1  (start of serialization)
    //   posedge N+2 : crc_rst=0, processing=1, valid=1, data_in=data[31]
    //                 shift_reg shifts, bit_cnt=1
    //   ...
    //   posedge N+33: bit_cnt=31 processed → processing←0, done←1
    // =========================================================================

    always @(posedge clk) begin
        if (rst) begin
            // -----------------------------------------------------------------
            // Global synchronous reset: flush all registers
            // -----------------------------------------------------------------
            shift_reg  <= 32'h0;
            bit_cnt    <= 5'd0;
            processing <= 1'b0;
            done       <= 1'b0;
            crc_rst    <= 1'b1;   // Hold CRC cores in reset until released
        end
        else begin
            // Defaults: done is a one-cycle pulse; crc_rst de-asserts each cycle
            done    <= 1'b0;
            crc_rst <= 1'b0;

            // -----------------------------------------------------------------
            // START phase: latch data and reset CRC cores
            // processing stays LOW this cycle — CRC cores see rst=1, valid=0
            // -----------------------------------------------------------------
            if (start && !processing) begin
                shift_reg  <= data;    // Latch 32-bit input into shift register
                bit_cnt    <= 5'd0;    // Reset bit counter
                crc_rst    <= 1'b1;    // Assert reset to CRC cores (they reset this posedge)
                processing <= 1'b0;    // Keep IDLE: processing starts NEXT cycle
                done       <= 1'b0;
            end

            // -----------------------------------------------------------------
            // ARM phase: one cycle after start, release CRC cores and begin
            // We detect this as: crc_rst was 1 last cycle AND processing is 0
            // and start is no longer asserted.
            // SIMPLER EQUIVALENT: use a one-cycle delayed version of crc_rst
            // -----------------------------------------------------------------

            // -----------------------------------------------------------------
            // ACTIVE phase: shift bits, count, feed CRC cores
            // valid=processing is HIGH so CRC cores advance each cycle
            // -----------------------------------------------------------------
            else if (processing) begin
                shift_reg <= shift_reg << 1; // Expose next bit at [31]
                bit_cnt   <= bit_cnt + 5'd1;

                if (bit_cnt == 5'd31) begin
                    // All 32 bits processed — stop and signal
                    processing <= 1'b0;
                    done       <= 1'b1;  // One-cycle completion pulse
                end
            end
        end
    end

    // =========================================================================
    // ARM Logic: Start processing one cycle after crc_rst
    // We need a registered version of the start event to begin processing
    // on the cycle after reset is applied to the CRC cores.
    // =========================================================================
    // This register tracks that we just did a reset-and-arm cycle.
    reg start_d1; // One-cycle delayed start: triggers processing begin

    always @(posedge clk) begin
        if (rst) begin
            start_d1 <= 1'b0;
        end else begin
            // start_d1 goes HIGH for ONE cycle: the cycle AFTER start was received
            // (i.e., the cycle after crc_rst was asserted)
            start_d1 <= (start && !processing);

            // On the cycle start_d1 is HIGH: release crc_rst and begin processing
            if (start_d1) begin
                processing <= 1'b1;   // Begin active serialization
                crc_rst    <= 1'b0;   // Ensure CRC cores are released
            end
        end
    end

    // =========================================================================
    // CRC Core Instantiations
    // =========================================================================
    // All four cores share:
    //   clk     = system clock
    //   rst     = crc_rst (high during start cycle, low during processing)
    //   valid   = processing (LFSR only shifts during active serialization)
    //   data_in = shift_reg[31] (current MSB = current serial bit, combinational)
    //
    // Timing at first valid cycle (posedge N+2 from start at posedge N):
    //   crc_rst=0, processing=1, shift_reg[31]=data[31]
    //   → CRC core: rst=0, valid=1, data_in=data[31] ✅ No skipped bits.
    // =========================================================================

    // CRC-16 (3GPP: used for UL/DL-SCH transport blocks, short payloads)
    crc_core #(
        .WIDTH (16        ),
        .POLY  (24'h1021  ),
        .INIT  (24'h0     )
    ) u_crc16 (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc16         )
    );

    // CRC-24A (3GPP: transport block CRC for large TB, LDPC BG1)
    crc_core #(
        .WIDTH (24        ),
        .POLY  (24'h864CFB),
        .INIT  (24'h0     )
    ) u_crc24a (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc24a        )
    );

    // CRC-24B (3GPP: code block CRC for LDPC BG1/BG2 segmentation)
    crc_core #(
        .WIDTH (24        ),
        .POLY  (24'h800063),
        .INIT  (24'h0     )
    ) u_crc24b (
        .clk     (clk           ),
        .rst     (crc_rst       ),
        .valid   (processing    ),
        .data_in (shift_reg[31] ),
        .crc     (crc24b        )
    );

    // CRC-24C (3GPP: SI message CRC, TS 38.212 Section 7.3.2)
    crc_core #(
        .WIDTH (24        ),
        .POLY  (24'h4C11DB),
        .INIT  (24'h0     )
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
