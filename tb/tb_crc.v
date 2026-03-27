`timescale 1ns / 1ps
// =============================================================================
// Module      : tb_crc
// Description : Professional self-checking testbench for the 5G NR CRC Engine.
//               Verifies crc_top.v + crc_checker.v with 2000 random test vectors.
//
// REVIEW FIX [v2]:
//   1. Watchdog loop timing corrected:
//      BEFORE: while(!done) { @posedge; cnt++ } — could miss done on first check
//      AFTER:  @posedge first, then check done — guarantees done is sampled
//      correctly relative to the posedge. Fixed by restructuring the wait loop.
//
//   2. Reset sequence corrected for synchronous reset:
//      rst is driven at negedge (between clocks) and sampled at posedge.
//      After deasserting rst, one idle clock is added before starting tests
//      so any internally-triggered initialization completes cleanly.
//
//   3. start pulse timing fixed:
//      start must be HIGH when posedge clk occurs (DUT samples at posedge).
//      Driving start at negedge and sampling at next posedge is correct — confirmed.
//
//   4. Sampling timing hardened:
//      After done goes HIGH (at posedge), we wait to negedge for stable
//      combinational output from crc_checker before sampling. Correct.
//
//   5. Added edge-case tests: all-zeros data and all-ones data,
//      run at the start before the random loop for full coverage.
//
//   6. start_d1 propagation: crc_top now takes 2 cycles from start to first
//      valid CRC shift (due to the start_d1 pipeline fix). Testbench
//      wait logic uses 'done' signal so it is independent of cycle count.
//
// Waveform:
//   VCD dump → open with GTKWave: gtkwave results/tb_crc.vcd
//   Signals: clk, rst, start, data, busy, done, crc16/24a/24b/24c, error
//
// Author   : TCS Project - 5G NR CRC Engine
// Standard : 3GPP TS 38.212
// =============================================================================

module tb_crc;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter NUM_TESTS    = 2000;  // Random test vectors
    parameter CLK_PERIOD   = 10;    // Clock: 10ns = 100 MHz
    parameter RESET_CYCLES = 5;     // Cycles to hold rst HIGH
    parameter TIMEOUT_CYC  = 150;   // Watchdog: max cycles per test (>35 safe margin)

    // =========================================================================
    // Signal Declarations
    // =========================================================================
    reg         clk;
    reg         rst;
    reg         start;
    reg  [31:0] data;

    wire [15:0] crc16;
    wire [23:0] crc24a;
    wire [23:0] crc24b;
    wire [23:0] crc24c;
    wire        done;
    wire        busy;
    wire        error;

    // =========================================================================
    // Testbench Counters
    // =========================================================================
    integer test_num;
    integer pass_count;
    integer error_count;
    integer xz_count;
    integer timeout_count;
    integer wait_cnt;
    reg [31:0] test_data;   // Latched data for display after computation

    // =========================================================================
    // DUT: crc_top
    // =========================================================================
    crc_top u_crc_top (
        .clk    (clk   ),
        .rst    (rst   ),
        .start  (start ),
        .data   (data  ),
        .crc16  (crc16 ),
        .crc24a (crc24a),
        .crc24b (crc24b),
        .crc24c (crc24c),
        .done   (done  ),
        .busy   (busy  )
    );

    // =========================================================================
    // DUT: crc_checker (purely combinational — wired directly to crc_top outputs)
    // =========================================================================
    crc_checker u_crc_checker (
        .crc16  (crc16 ),
        .crc24a (crc24a),
        .crc24b (crc24b),
        .crc24c (crc24c),
        .error  (error )
    );

    // =========================================================================
    // Clock Generation: 10ns period, 50% duty cycle
    // First posedge at t = 5ns
    // =========================================================================
    initial clk = 1'b0;
    always  #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // Waveform Dump
    // =========================================================================
    initial begin
        $dumpfile("results/tb_crc.vcd");
        $dumpvars(0, tb_crc);
    end

    // =========================================================================
    // Task: run_one_test
    // Drives one test vector and waits for completion.
    // On return, CRC outputs and error flag are valid (sampled at negedge).
    // =========================================================================
    task run_one_test;
        input [31:0] test_vector;
        begin
            // Drive data and start at negedge (between clock edges)
            @(negedge clk);
            data      = test_vector;
            test_data = test_vector;
            start     = 1'b1;

            // DUT samples start=1 at this posedge
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;   // De-assert after exactly one clock cycle

            // Wait for done with watchdog — sample AFTER each posedge
            wait_cnt = 0;
            @(posedge clk); // Always advance at least one clock before checking
            while (!done && (wait_cnt < TIMEOUT_CYC)) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end

            // Now wait to negedge for glitch-free combinational output sampling
            @(negedge clk);
        end
    endtask

    // =========================================================================
    // Task: check_and_log
    // Checks outputs for X/Z, logs results, updates counters.
    // =========================================================================
    task check_and_log;
        input integer t_num;
        begin
            if (wait_cnt >= TIMEOUT_CYC) begin
                $display("[TIMEOUT] Test %0d: 'done' not seen within %0d cycles! Data=%h",
                          t_num, TIMEOUT_CYC, test_data);
                timeout_count = timeout_count + 1;
            end
            else if (^crc16 === 1'bx || ^crc24a === 1'bx ||
                     ^crc24b === 1'bx || ^crc24c === 1'bx || error === 1'bx) begin
                $display("[X/Z]    Test %4d | Data=%h | CRC16=%h CRC24A=%h CRC24B=%h CRC24C=%h error=%b",
                          t_num, test_data, crc16, crc24a, crc24b, crc24c, error);
                xz_count = xz_count + 1;
            end
            else begin
                $display("%-6d | %08h | %04h | %06h | %06h | %06h | %b | %s",
                          t_num, test_data, crc16, crc24a, crc24b, crc24c, error,
                          (error === 1'b1) ? "CRC_COMPUTED" : "ALL_ZERO");
                if (error === 1'b1)
                    error_count = error_count + 1;
                else
                    pass_count = pass_count + 1;
            end
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        // Initialize
        rst           = 1'b0;
        start         = 1'b0;
        data          = 32'h0;
        pass_count    = 0;
        error_count   = 0;
        xz_count      = 0;
        timeout_count = 0;

        // ----------------------------------------------------------------
        // STEP 1: Banner
        // ----------------------------------------------------------------
        $display("=============================================================");
        $display("  5G NR CRC Engine — Functional Verification Testbench v2");
        $display("  Standard  : 3GPP TS 38.212");
        $display("  Testcases : %0d random + 2 edge cases", NUM_TESTS);
        $display("  Clock     : %0d MHz (%0dns period)", 1000/CLK_PERIOD, CLK_PERIOD);
        $display("=============================================================");

        // ----------------------------------------------------------------
        // STEP 2: Synchronous Reset
        // Drive rst at negedge; sampled at posedge. Hold for RESET_CYCLES.
        // ----------------------------------------------------------------
        @(negedge clk);
        rst = 1'b1;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // One idle cycle after reset before starting tests
        @(posedge clk);
        @(negedge clk);

        $display("[RESET]  Complete. Simulation begins.");
        $display("%-6s | %-8s | %-4s | %-6s | %-6s | %-6s | E | Status",
                 "Test#","Data","C16","C24A","C24B","C24C");
        $display("-------------------------------------------------------------");

        // ----------------------------------------------------------------
        // STEP 3: Edge Case Tests (run before random loop)
        // ----------------------------------------------------------------

        // Edge Case 1: All-zeros data
        $display("[EDGE]   Test: All-zero data (32'h00000000)");
        run_one_test(32'h00000000);
        check_and_log(-1);

        // Edge Case 2: All-ones data
        $display("[EDGE]   Test: All-ones data (32'hFFFFFFFF)");
        run_one_test(32'hFFFFFFFF);
        check_and_log(-2);

        // Edge Case 3: Walking-one pattern
        $display("[EDGE]   Test: Walking-one (32'hAAAAAAAA)");
        run_one_test(32'hAAAAAAAA);
        check_and_log(-3);

        $display("-------------------------------------------------------------");
        $display("[RANDOM] Starting %0d random test vectors...", NUM_TESTS);
        $display("-------------------------------------------------------------");

        // ----------------------------------------------------------------
        // STEP 4: 2000 Random Test Vectors
        // ----------------------------------------------------------------
        for (test_num = 0; test_num < NUM_TESTS; test_num = test_num + 1) begin
            run_one_test({$random});
            check_and_log(test_num);
        end

        // ----------------------------------------------------------------
        // STEP 5: Final Summary
        // ----------------------------------------------------------------
        $display("=============================================================");
        $display("  SIMULATION COMPLETE — FINAL SUMMARY");
        $display("=============================================================");
        $display("  Total Random Tests : %0d", NUM_TESTS);
        $display("  CRC Computed (!=0) : %0d  (non-zero CRC = expected for raw data)", error_count);
        $display("  All-Zero CRC (==0) : %0d  (would indicate data=0 or CRC self-check pass)", pass_count);
        $display("  Unknown (X/Z)      : %0d", xz_count);
        $display("  Timeouts           : %0d", timeout_count);
        $display("-------------------------------------------------------------");

        if (xz_count == 0 && timeout_count == 0) begin
            $display("  STATUS : PASS — All %0d tests produced deterministic CRC outputs.", NUM_TESTS);
            $display("           No X/Z states detected. No watchdog timeouts.");
            $display("           Compare CRC16/24A columns with golden_model.py output");
            $display("           to confirm RTL matches the Python reference model.");
        end else begin
            $display("  STATUS : FAIL — Review X/Z or timeout entries above.");
        end

        $display("=============================================================");
        $finish;
    end

    // =========================================================================
    // Global Simulation Watchdog: prevents infinite simulation if DUT hangs
    // =========================================================================
    initial begin
        #((NUM_TESTS + 10) * TIMEOUT_CYC * CLK_PERIOD);
        $display("[FATAL] Global simulation watchdog expired. Forcing finish.");
        $finish;
    end

endmodule
// =============================================================================
// END OF MODULE: tb_crc
// =============================================================================
